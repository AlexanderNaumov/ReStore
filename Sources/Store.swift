//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import Foundation
import RxSwift

public final class Store: Identifiable {
    
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
    
    private var states: [String: State] = [:]
    private var stateObservers: [StateObserverType] = []

    private func update(state: State, of type: State.Type) {
        let typeStr = String(describing: type)
        switch storeType {
        case .default,
             .local where contains(type):
            states[typeStr] = state
        case .local where Store.default.contains(type):
            Store.default.states[typeStr] = state
        default:
            break
        }
    }
    
    private func contains(_ type: State.Type) -> Bool {
        states[String(describing: type)] != nil
    }
    
    private func notify(event: AnyEvent) {
        switch storeType {
        case .default,
             .local where contains(event.type):
            stateObservers.filter { $0.type == event.type }.forEach { $0.notify(event: event) }
        case .local where Store.default.contains(event.type):
            Store.default.stateObservers.filter { $0.type == event.type }.forEach { $0.notify(event: event) }
        default:
            break
        }
    }
    
    private func append<S: State>(observer: StateObserver<S>) {
        switch storeType {
        case .default,
             .local where contains(S.self):
            stateObservers.append(observer)
        case .local where Store.default.contains(S.self):
            Store.default.stateObservers.append(observer)
        default:
            break
        }
    }
    
    private func remove(observer: StateObserverType) {
        if case .default = storeType, let index = stateObservers.firstIndex(where: { $0 === observer }) {
            stateObservers.remove(at: index)
        } else if case .local = storeType, let index = stateObservers.firstIndex(where: { $0 === observer }) {
            stateObservers.remove(at: index)
        } else if case .local = storeType, let index = Store.default.stateObservers.firstIndex(where: { $0 === observer }) {
            Store.default.stateObservers.remove(at: index)
        }
    }
    
    public func register(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    public func state<S: State>() -> S {
        let typeStr = String(describing: S.self)
        switch storeType {
        case .default:
            return states[typeStr] as! S
        case .local:
            return states[typeStr] as? S ?? Store.default.state()
        }
    }
    
    public func observe<S: State>() -> Infallible<Event<S>> {
        return Infallible<Event<S>>.create { [weak self] observer in
            let observer = StateObserver<S> { e in
                observer(.next(e))
            }
            self?.append(observer: observer)
            if let `self` = self {
                let state: S = self.state()
                observer.notify(event: AnyEvent(type: S.self, state: state, payload: nil))
            }
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.remove(observer: observer)
            }
        }
    }
    
    // Action

    private lazy var actionObservers: [ActionObserver] = []
    
    private func append(observer: ActionObserver) {
        Store.default.actionObservers.append(observer)
    }
    
    private func remove(observer: ActionObserver) {
        guard let index = Store.default.actionObservers.firstIndex(where: { $0 === observer }) else { return }
        Store.default.actionObservers.remove(at: index)
    }
    
    private func notify(type: ActionType.Type) {
        Store.default.actionObservers.filter { $0.types.contains { $0 == type } }.forEach { $0.notify(type: type) }
    }
    
    public func didChange(of type: ActionType.Type...) -> Infallible<ActionType.Type> {
        return Infallible.create { [weak self] observer in
            let observer = ActionObserver(types: type) { type in
                observer(.next(type))
            }
            self?.append(observer: observer)
            if type.contains(where: { $0.eq(OnObserve.self) }) {
                observer.notify(type: OnObserve.self)
            }
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.remove(observer: observer)
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
    
    func notify(action: ActionType, payload: Any? = nil) {
        Store.default.middlewares.forEach { $0(action, payload, self) }
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
        notify(type: CancelTask.self) // ???
    }
    
    // Dispatch
    
    public func dispatch<A: Action>(_ action: A) {
        do {
            let state: State
            let payload: Any?
            switch try action.reduce(store: self) {
            case let result as AnyResult:
                state = result.anyState
                payload = result.anyPayload
            case let _state as State:
                state = _state
                payload = nil
            }
            let stateType = type(of: state)
            update(state: state, of: stateType)
            notify(event: AnyEvent(type: stateType, state: state, payload: payload))
            notify(type: A.self)
            notify(action: action, payload: payload)
        } catch {
            notify(type: ErrorAction<A>.self)
            notify(action: ErrorAction<A>(error: error))
        }
    }
    
    public func dispatch(_ action: AsyncAction) {
        action.execute(store: self)
        notify(type: type(of: action))
        notify(action: action)
    }
    
    public func dispatch<A: Action>() -> Binder<A> {
        Binder(self) { `self`, action in
            self.dispatch(action)
        }
    }
    
    public func dispatch() -> Binder<AsyncAction> {
        Binder(self) { `self`, action in
            self.dispatch(action)
        }
    }
    
    // Remove
    
    public func removeAll() {
        states.removeAll()
        middlewares.removeAll()
        workers.removeAllObjects()
    }
    
    public func removeObservers() {
        stateObservers.removeAll()
        actionObservers.removeAll()
    }
}
