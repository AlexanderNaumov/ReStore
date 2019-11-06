//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import Foundation
import When
import RxSwift

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

public final class StoreState<T: State> {
    public let value: T
    private weak var store: AnyStore?
    init(_ store: AnyStore, value: T) {
        self.value = value
        self.store = store
    }
    public func asObservable() -> Observable<T> {
        return Observable.create { [weak self] observer in
            let observer = StateObserver<T> { state in
                observer.onNext(state)
            }
            self!.store?.observe(observer)
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.store?.remove(observer: observer)
            }
        }
    }
}


protocol AnyStore: class {
    func observe<S: State>(_ observer: StateObserver<S>)
    func remove(observer: AnyStateObserver)
}

public final class Store<S: State>: AnyStore {
    private var _state: S

    public init(state: S) {
        _state = state
    }

    private typealias ObserverContainer = (
        observer: AnyStoreObserver,
        stateType: State.Type?,
        eventType: AnyEvent.Type,
        notificationType: AnyNotification.Type,
        notify: (AnyNotification) -> Void
    )
    
    private typealias StateObserverContainer = (
        observer: AnyStateObserver,
        stateType: State.Type,
        notify: (State) -> Void
    )

    private typealias StateContainer = (
        type: State.Type,
        get: () -> State,
        set: (State) -> Void
    )

    private var customStates: [StateContainer] = []
    private var observers: [ObserverContainer] = []
    private var stateObservers: [StateObserverContainer] = []
    private let workers = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
    private var middlewares: [Middleware<S>] = []
    private var providers: [Provider] = []
    
    public func state<S: State>() -> StoreState<S> {
        return StoreState(self, value: state(of: S.self) as! S)
    }
    
    public func cancelTask(with type: TaskType) {
        workers.dictionaryRepresentation()
            .filter { $0.key as! NSString == type.rawValue as NSString }.values
            .map { $0 as! AnyPromise }
            .forEach { $0.cancel() }
        notify(event: .e2(.cancelTask, type), eventType: StoreEvent.self)
    }

    public func observe<O: StoreObserver, S: State, E: Event>(_ observer: O) where O.S == S, O.E == E {
        observers.append((observer, O.S.self, O.E.self, O.N.self, { observer.notify(notification: $0 as! O.N) }))
        notify(event: .e2(.onObserve, observer), eventType: StoreEvent.self)
    }
    
    func observe<O: StoreObserver, E: Event>(_ observer: O) where O.E == E {
        observers.append((observer, nil, O.E.self, O.N.self, { observer.notify(notification: $0 as! O.N) }))
        notify(event: .e2(.onObserve, observer), eventType: StoreEvent.self)
    }
    
    func observe<S: State>(_ observer: StateObserver<S>) {
        stateObservers.append((observer, S.self, { observer.notify(state: $0 as! S) }))
        observer.notify(state: state(of: S.self) as! S)
    }
    
    func remove(observer: AnyStateObserver) {
        if let index = stateObservers.firstIndex(where: { $0.observer === observer }) {
            stateObservers.remove(at: index)
        }
    }
    
    public func remove(_ observer: AnyStoreObserver) {
        guard let index = observers.firstIndex(where: { $0.observer === observer }) else { return }
        observers.remove(at: index)
    }

    public func removeAllObservers() {
        observers.removeAll()
    }

    public func register<C: State>(keyPath: WritableKeyPath<S, C>) {
        customStates.append((C.self, { self._state[keyPath: keyPath] }, { self._state[keyPath: keyPath] = $0 as! C }))
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
        var result: Swift.Result<Any?, Error> = .success(nil)

        if let mutator = action.mutator {
            var state = self.state(of: mutator.stateType)
            do {
                let value = try mutator.commit(action, &state)
                set(state: state, of: mutator.stateType)
                result = .success(value)
                notify(state: state)
            } catch When.PromiseError.cancelled {
                return
            } catch {
                set(state: state, of: mutator.stateType)
                result = .failure(error)
            }
        }

        if let executor = action.executor {
            let state = executor.stateType.map { self.state(of: $0) }
            let provider = executor.providerType.flatMap { t in providers.first { type(of: $0) == t } }
            executor.execute(provider, self, action, state)
        }

        let event: AnyEitherEvent
        switch result {
        case let .success(value: value):
            event = .e1(action.event, value)
        case let .failure(error: error):
            event = .e2(.error, error)
        }
        
        notify(event: event, eventType: type(of: action.event), value: (action as? AnyActionValue)?.anyValue)
    }
    
    private func notify(state: State) {
        stateObservers.first { $0.stateType == type(of: state) }?.notify(state)
    }
    
    private func notify(event: AnyEitherEvent,  eventType: AnyEvent.Type, value: Any? = nil) {
        (eventType == StoreEvent.self ? observers : observers.filter { $0.eventType == eventType }).forEach {
            guard let notification = $0.notificationType.init(event: event, state: state(of: $0.stateType ?? S.self)) else { return }
            $0.notify(notification)
        }
        middlewares.forEach { $0(_state, value, event) }
    }

    private func state(of type: State.Type) -> State {
        if type == S.self {
            return _state
        } else if let index = customStates.firstIndex(where: { $0.type == type }) {
            return customStates[index].get()
        }
        fatalError()
    }

    private func set(state: State, of type: State.Type) {
        if type == S.self {
            self._state = state as! S
        } else if let index = customStates.firstIndex(where: { $0.type == type }) {
            customStates[index].set(state)
        }
    }
}
