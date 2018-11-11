//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import Foundation
import When

public typealias Middleware<S: State> = (_ state: S, _ payload: Any?, _ event: AnyEventResult) -> Void

public protocol State {}

public struct TaskType: RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all = TaskType(rawValue: "allWorkers")
}

public protocol AnyStore: class {
    func dispatch(_ action: Action)
}

public final class Store<S: State>: AnyStore {
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
    
    public func cancelTask(with type: TaskType) {
        workers.dictionaryRepresentation()
            .filter { $0.key as! NSString == type.rawValue as NSString }.values
            .map { $0 as! AnyPromise }
            .forEach { $0.cancel() }
        notify(eventResult: .event(.e2(.cancelTask(type))), eventType: StoreEvent.self)
    }

    public func observe<O: StoreObserver, S: State, E: Event>(_ observer: O) where O.S == S, O.E == E {
        observers.append((observer, O.S.self, O.E.self, O.N.self, { observer.notify(notification: $0 as! O.N) }))
        notify(eventResult: .event(.e2(.onObserve(observer))), eventType: StoreEvent.self)
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

        if let executor = action.executor {
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

        let eventResult: AnyEventResult
        do {
            let value = try result<!
            if let valueType = action.event.valueType {
                guard let v = value, type(of: v) == valueType else { fatalError() }
            }
            eventResult = .event(.e1(action.event.event(value)))
        } catch {
            eventResult = .error(error)
        }
        
        notify(eventResult: eventResult, eventType: action.event.eventType, value: (action as? AnyActionValue)?.anyValue)
    }
    
    private func notify(eventResult: AnyEventResult,  eventType: AnyEvent.Type, value: Any? = nil) {
        (eventType == StoreEvent.self ? observers : observers.filter { $0.eventType == eventType }).forEach {
            guard let notification = $0.notificationType.init(event: eventResult, state: state(of: $0.stateType)) else { return }
            $0.notify(notification)
        }
        middlewares.forEach { $0(state, value, eventResult) }
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