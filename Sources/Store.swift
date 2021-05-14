//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import Foundation
import RxSwift

public typealias Middleware = (_ store: MutatorStore, _ payload: Any?, _ event: AnyEitherEvent) -> Void

public protocol State {}

public protocol ExecutorStore: AnyObject {
    func dispatch(_ action: Action)
    func state<S: State>() -> StoreState<S>
    func state<S: State>() -> S
    func submitJob<J: ObservableType>(_ job: J, type: JobType, completion: @escaping (RxSwift.Event<J.Element>) -> Void)
    func cancelJob(with type: JobType)
}

public protocol MutatorStore: AnyObject {
    func state<S: State>() -> S
}

public struct JobType: RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all = JobType(rawValue: "allWorkers")
}

public typealias StoreEvent<E> = Observable<EitherEvent<E>>
public typealias StoreState<S: State> = Observable<S>

public final class Store: Identifiable, ExecutorStore, MutatorStore {
    
    public static let `default` = Store(storeType: .default)
    private let storeType: StoreType
    
    private enum StoreType {
        case `default`, local
    }
    
    private init(storeType: StoreType) {
        self.storeType = storeType
    }
    
    public init() {
        storeType = .local
    }
    
    // State
    
    private typealias StateObserverContainer = (
        observer: AnyStateObserver,
        stateType: State.Type,
        notify: (State) -> Void
    )
    
    private var states: [String: State] = [:]
    private var stateObservers: [StateObserverContainer] = []
    
    private func state(of type: State.Type) -> State {
        let _type = String(describing: type)
        switch storeType {
        case .default:
            return states[_type]!
        case .local:
            return states[_type] ?? Store.default.state(of: type)
        }
    }

    private func update(state: State, of type: State.Type) {
        let _type = String(describing: type)
        switch storeType {
        case .default,
             .local where contains(type):
            states[_type] = state
        case .local where Store.default.contains(type):
            Store.default.states[_type] = state
        default:
            break
        }
    }
    
    private func contains(_ type: State.Type) -> Bool {
        states[String(describing: type)] != nil
    }
    
    private func notify(state: State) {
        let t = type(of: state)
        switch storeType {
        case .default,
             .local where contains(t):
            stateObservers.filter { $0.stateType == t }.forEach { $0.notify(state) }
        case .local where Store.default.contains(t):
            Store.default.stateObservers.filter { $0.stateType == t }.forEach { $0.notify(state) }
        default:
            break
        }
    }
    
    private func observe<S: State>(_ observer: StateObserver<S>) {
        switch storeType {
        case .default,
             .local where contains(S.self):
            stateObservers.append((observer, S.self, { observer.notify(state: $0) }))
            observer.notify(state: state(of: S.self))
        case .local where Store.default.contains(S.self):
            Store.default.stateObservers.append((observer, S.self, { observer.notify(state: $0) }))
            observer.notify(state: state(of: S.self))
        default:
            break
        }
    }
    
    private func remove(observer: AnyStateObserver) {
        if case .default = storeType, let index = stateObservers.firstIndex(where: { $0.observer === observer }) {
            stateObservers.remove(at: index)
        } else if case .local = storeType, let index = stateObservers.firstIndex(where: { $0.observer === observer }) {
            stateObservers.remove(at: index)
        } else if case .local = storeType, let index = Store.default.stateObservers.firstIndex(where: { $0.observer === observer }) {
            Store.default.stateObservers.remove(at: index)
        }
    }
    
    public func register(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    public func state<S: State>() -> S {
        return state(of: S.self) as! S
    }
    
    public func state<S: State>() -> StoreState<S> {
        return Observable.create { [weak self] observer -> Disposable in
            let observer = StateObserver<S> { state in
                observer.on(.next(state))
            }
            self?.observe(observer)
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.remove(observer: observer)
            }
        }
    }
    
    // Event
    
    private typealias EventObserverContainer = (
        observer: AnyEventObserver,
        eventType: AnyEvent.Type,
        notify: (AnyEitherEvent) -> Void
    )

    private lazy var eventObservers: [EventObserverContainer] = []
    
    private func observe<E: Event>(_ observer: EventObserver<E>) {
        Store.default.eventObservers.append((observer, E.self, { observer.notify(event: $0) }))
        notify(event: .e2(.onObserve, observer), eventType: InnerEvent.self, value: nil)
    }
    
    private func remove(_ observer: AnyEventObserver) {
        guard let index = Store.default.eventObservers.firstIndex(where: { $0.observer === observer }) else { return }
        Store.default.eventObservers.remove(at: index)
    }
    
    private func notify(event: AnyEitherEvent, eventType: AnyEvent.Type, value: Any?) {
        (eventType == InnerEvent.self ? Store.default.eventObservers : Store.default.eventObservers.filter { $0.eventType == eventType }).forEach { $0.notify(event) }
        Store.default.middlewares.forEach { $0(self, value, event) }
    }
    
    public func event<E: Event>() -> StoreEvent<E> {
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
    
    // Middleware
    
    private lazy var middlewares: [Middleware] = []

    public func register(middleware: @escaping Middleware) {
        guard case .default = storeType else {
            print("Store: Local store does not support")
            return
        }
        middlewares.append(middleware)
    }
    
    // Job
    
    private lazy var workers = NSMapTable<NSString, AnyObject>.strongToWeakObjects()
    
    public func submitJob<J: ObservableType>(_ job: J, type: JobType, completion: @escaping (RxSwift.Event<J.Element>) -> Void) {
        let obj = job.subscribe(completion) as AnyObject
        Store.default.workers.setObject(obj, forKey: type.rawValue as NSString)
    }
    
    public func cancelJob(with type: JobType) {
        let jobs = Store.default.workers.dictionaryRepresentation().filter { $0.key as! NSString == type.rawValue as NSString }.values
        jobs.compactMap { $0 as? Disposable }.forEach { $0.dispose() }
        notify(event: .e2(.cancelTask, type), eventType: InnerEvent.self, value: nil)
    }
    
    // Dispatch
    
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
                update(state: state, of: mutator.stateType)
                notify(state: state)
                result = .success(payload)
            } catch {
                result = .failure(error)
            }
        }

        action.executor?(self, action)

        let event: AnyEitherEvent
        switch result {
        case let .success(value: value):
            event = .e1(action.event, value)
        case let .failure(error: error):
            event = .e2(.error, error)
        }
        
        notify(event: event, eventType: type(of: action.event), value: (action as? AnyActionValue)?.anyValue)
    }
    
    public var dispatch: AnyObserver<Action> {
        return AnyObserver { [weak self] e in
            guard let self = self, case let .next(action) = e else { return }
            self.dispatch(action)
        }
    }
    
    // Remove
    
    public func removeAll() {
        states.removeAll()
        middlewares.removeAll()
        workers.removeAllObjects()
    }
    
    public func removeAllObservers() {
        eventObservers.removeAll()
        stateObservers.removeAll()
    }
}
