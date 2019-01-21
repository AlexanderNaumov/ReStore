//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import Foundation
import When

public typealias Middleware<S: State> = (_ state: S, _ payload: Any?, _ event: AnyEitherEvent) -> Void

public protocol State {}
public protocol Provider {}
public protocol StoreAction: class {
    func dispatch(_ action: Action)
    func cancelTask(with type: TaskType)
    func provide<T>(_ c: @autoclosure () -> Promise<T>) -> Promise<T>
    func provide<T>(_ c: @autoclosure () -> Promise<T>, task: TaskType) -> Promise<T>
}

extension Store: StoreAction {}

public struct TaskType: RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all = TaskType(rawValue: "allWorkers")
}

public final class Store<S: State> {
    public private(set) var state: S

    public init(state: S, configure: ((Store<S>) -> Void)? = nil) {
        self.state = state
        configure?(self)
    }

    private typealias ObserverContainer = (
        observer: AnyStoreObserver,
        stateType: State.Type,
        eventType: AnyEvent.Type,
        notificationType: AnyNotification.Type,
        notify: (AnyNotification) -> Void
    )

    private typealias StateContainer = (
        type: State.Type,
        get: () -> State,
        set: (State) -> Void
    )

    private var customStates: [StateContainer] = []
    private var observers: [ObserverContainer] = []
    private let workers = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
    private var middlewares: [Middleware<S>] = []
    private var providers: [Provider] = []
    
    public func cancelTask(with type: TaskType) {
        workers.dictionaryRepresentation()
            .filter { $0.key as! NSString == type.rawValue as NSString }.values
            .map { $0 as! AnyPromise }
            .forEach { $0.cancel() }
        notify(event: .e2(.cancelTask(type)), eventType: StoreEvent.self)
    }

    public func observe<O: StoreObserver, S: State, E: Event>(_ observer: O) where O.S == S, O.E == E {
        observers.append((observer, O.S.self, O.E.self, O.N.self, { observer.notify(notification: $0 as! O.N) }))
        notify(event: .e2(.onObserve(observer)), eventType: StoreEvent.self)
    }
    
    public func remove(_ observer: AnyStoreObserver) {
        guard let index = observers.index(where: { $0.observer === observer }) else { return }
        observers.remove(at: index)
    }

    public func removeAllObservers() {
        observers.removeAll()
    }

    public func register<C: State>(keyPath: WritableKeyPath<S, C>) {
        customStates.append((C.self, { self.state[keyPath: keyPath] }, { self.state[keyPath: keyPath] = $0 as! C }))
    }
    
    public func register(middleware: @escaping Middleware<S>) {
        middlewares.append(middleware)
    }
    
    public func register(provider: Provider) {
        providers.append(provider)
    }
    
    public func provide<T>(_ p: @autoclosure () -> Promise<T>) -> Promise<T> {
        let promise = p()
        workers.setObject(promise, forKey: TaskType.all.rawValue as NSString)
        return promise
    }
    public func provide<T>(_ p: @autoclosure () -> Promise<T>, task: TaskType) -> Promise<T> {
        let promise = p()
        workers.setObject(promise, forKey: task.rawValue as NSString)
        return promise
    }
    
    public func dispatch(_ action: Action) {
        var result: Result<Any?> = .success(value: nil)

        if let mutator = action.mutator {
            var state = self.state(of: mutator.stateType)
            do {
                let value = try mutator.commit(action, &state)
                set(state: state, of: mutator.stateType)
                result = .success(value: value)
            } catch When.PromiseError.cancelled {
                return
            } catch {
                set(state: state, of: mutator.stateType)
                result = .failure(error: error)
            }
        }

        if let executor = action.oldExecutor {
            var provider: Action.AnyProvider?
            if let container = action.provider {
                provider = { v in
                    let result = container.provider(v)
                    if let promise = result as? AnyPromise {
                        self.workers.setObject(promise, forKey: TaskType.all.rawValue as NSString)
                        if let type = container.type {
                            self.workers.setObject(promise, forKey: type.rawValue as NSString)
                        }
                    }
                    return result
                }
            }
            let state = executor.stateType.map { self.state(of: $0) }
            executor.execute(provider, dispatch, cancelTask, action, state)
        }
        
        if let executor = action.executor {
            let state = executor.stateType.map { self.state(of: $0) }
            let provider = executor.providerType.flatMap { t in providers.first { type(of: $0) == t } }
            executor.execute(provider, self, action, state)
        }

        let event: AnyEitherEvent
        do {
            let value = try result<!
            if let valueType = action.event.valueType {
                guard let v = value, type(of: v) == valueType else { fatalError() }
            }
            event = .e1(action.event.event(value))
        } catch {
            event = .e2(.error(error))
        }
        
        notify(event: event, eventType: action.event.eventType, value: (action as? AnyActionValue)?.anyValue)
    }
    
    private func notify(event: AnyEitherEvent,  eventType: AnyEvent.Type, value: Any? = nil) {
        (eventType == StoreEvent.self ? observers : observers.filter { $0.eventType == eventType }).forEach {
            guard let notification = $0.notificationType.init(event: event, state: state(of: $0.stateType)) else { return }
            $0.notify(notification)
        }
        middlewares.forEach { $0(state, value, event) }
    }

    private func state(of type: State.Type) -> State {
        if type == S.self {
            return state
        } else if let index = customStates.index(where: { $0.type == type }) {
            return customStates[index].get()
        }
        fatalError()
    }

    private func set(state: State, of type: State.Type) {
        if type == S.self {
            self.state = state as! S
        } else if let index = customStates.index(where: { $0.type == type }) {
            customStates[index].set(state)
        }
    }
}
