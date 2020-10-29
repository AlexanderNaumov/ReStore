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

public typealias Middleware = (_ store: MutatorStore, _ payload: Any?, _ event: AnyEitherEvent) -> Void

public protocol State {}
public protocol Provider {}
public protocol ExecutorStore: class {
    func dispatch(_ action: Action)
    func cancelJob(with type: JobType)
    func provide<T>(_ c: @autoclosure () -> Promise<T>) -> Promise<T>
    func provide<T>(_ c: @autoclosure () -> Promise<T>, type: JobType) -> Promise<T>
    func state<S: State>() -> StoreState<S>
    func state<S: State>() -> S
    func submitJob<J: ObservableType>(_ job: J, type: JobType, completion: @escaping (RxSwift.Event<J.Element>) -> Void)
}

public protocol MutatorStore: class {
    func state<S: State>() -> S
}

public struct JobType: RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all = JobType(rawValue: "allWorkers")
}

public final class StoreState<T: State>: ObservableType {
    public let value: T
    private weak var store: Store?
    init(_ store: Store, value: T) {
        self.value = value
        self.store = store
    }
    
    public typealias Element = T
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Element == Observer.Element {
        let observer = StateObserver<T> { state in
            observer.onNext(state)
        }
        store?.observe(observer)
        return Disposables.create { [weak self, weak observer] in
            guard let observer = observer else { return }
            self?.store?.remove(observer: observer)
        }
    }
}

public final class Store: ExecutorStore, MutatorStore {
    
    public static let `default` = Store()
    
    private init() {}
    
    private typealias EventObserverContainer = (
        observer: AnyEventObserver,
        eventType: AnyEvent.Type,
        notify: (AnyEitherEvent) -> Void
    )
    
    private typealias StateObserverContainer = (
        observer: AnyStateObserver,
        stateType: State.Type,
        notify: (State) -> Void
    )

    private var states: [String: State] = [:]
    private var eventObservers: [EventObserverContainer] = []
    private var stateObservers: [StateObserverContainer] = []
    private let workers = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
    private var middlewares: [Middleware] = []
    private var providers: [Provider] = []
    
    public func removeAll() {
        states.removeAll()
        middlewares.removeAll()
        providers.removeAll()
        workers.removeAllObjects()
    }
    
    public func state<S: State>() -> StoreState<S> {
        return StoreState(self, value: state(of: S.self) as! S)
    }
    
    public func state<S: State>() -> S {
        return state(of: S.self) as! S
    }
    
    public func cancelJob(with type: JobType) {
        let jobs = self.workers.dictionaryRepresentation().filter { $0.key as! NSString == type.rawValue as NSString }.values
        jobs.compactMap { $0 as? AnyPromise }.forEach { $0.cancel() }
        jobs.compactMap { $0 as? Disposable }.forEach { $0.dispose() }
        notify(event: .e2(.cancelTask, type), eventType: InnerEvent.self)
    }
    
    func observe<E: Event>(_ observer: EventObserver<E>) {
        eventObservers.append((observer, E.self, { observer.notify(event: $0) }))
        notify(event: .e2(.onObserve, observer), eventType: InnerEvent.self)
    }
    
    func observe<S: State>(_ observer: StateObserver<S>) {
        stateObservers.append((observer, S.self, { observer.notify(state: $0) }))
        observer.notify(state: state(of: S.self) as! S)
    }
    
    public func removeAllObservers() {
        eventObservers.removeAll()
        stateObservers.removeAll()
    }
    
    func remove(observer: AnyStateObserver) {
        guard let index = stateObservers.firstIndex(where: { $0.observer === observer }) else { return }
        stateObservers.remove(at: index)
    }
    
    public func remove(_ observer: AnyEventObserver) {
        guard let index = eventObservers.firstIndex(where: { $0.observer === observer }) else { return }
        eventObservers.remove(at: index)
    }

    public func register(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    public func register(middleware: @escaping Middleware) {
        middlewares.append(middleware)
    }
    
    public func register(provider: Provider) {
        providers.append(provider)
    }
    
    public func provide<T>(_ p: @autoclosure () -> Promise<T>) -> Promise<T> {
        let promise = p()
        workers.setObject(promise, forKey: JobType.all.rawValue as NSString)
        return promise
    }
    public func provide<T>(_ p: @autoclosure () -> Promise<T>, type: JobType) -> Promise<T> {
        let promise = p()
        workers.setObject(promise, forKey: type.rawValue as NSString)
        return promise
    }
    
    public func submitJob<J: ObservableType>(_ job: J, type: JobType, completion: @escaping (RxSwift.Event<J.Element>) -> Void) {
        let obj = job.subscribe(completion) as AnyObject
        workers.setObject(obj, forKey: type.rawValue as NSString)
    }
    
    public func dispatch(_ action: Action) {
        var result: Swift.Result<Any?, Error> = .success(nil)
        
        if let mutator = action.mutator {
            do {
                let mutate = try mutator.commit(action, self)
                let state: State
                let payload: Any?
                switch mutate {
                case let .state(s):
                    state = s
                    payload = nil
                case let .result(r):
                    state = r.anyState
                    payload = r.anyPayload
                }
                set(state: state, of: mutator.stateType)
                notify(state: state)
                result = .success(payload)
            } catch When.PromiseError.cancelled {
                return
            } catch {
                result = .failure(error)
            }
        }

        if let executor = action.executor {
            let provider = executor.providerType.flatMap { t in providers.first { type(of: $0) == t } }
            executor.execute(provider, self, action)
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
        stateObservers.filter { $0.stateType == type(of: state) }.forEach { $0.notify(state) }
    }
    
    private func notify(event: AnyEitherEvent,  eventType: AnyEvent.Type, value: Any? = nil) {
        (eventType == InnerEvent.self ? eventObservers : eventObservers.filter { $0.eventType == eventType }).forEach {
            $0.notify(event)
        }
        middlewares.forEach { $0(self, value, event) }
    }

    private func state(of type: State.Type) -> State {
        return states[String(describing: type)]!
    }

    private func set(state: State, of type: State.Type) {
        states[String(describing: type)] = state
    }
}

import RxCocoa

public typealias StoreEvent<E> = Observable<Either<E, InnerEvent>>

extension Store {
    public var dispatch: Binder<Action> {
        return Binder(self) { store, action in
            store.dispatch(action)
        }
    }
    
    public func event<E: Event>() -> Observable<EitherEvent<E>> {
        return Observable<EitherEvent<E>>.create { [weak self] observer in
            let observer = EventObserver<E> { e in
                observer.onNext(e)
            }
            self?.observe(observer)
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.remove(observer)
            }
        }
    }
}
