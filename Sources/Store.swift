//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public typealias Payload = Any

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
    
    private var states: [String: State] = [:]
    private var observables: [ObservableType: [(Any, AnyObservable)]] = [:]
    
    private func update(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    private func notify(action: ActionType, payload: Any? = nil, state: State? = nil) {
        if let items = observables[.action] as? [([ActionType.Type], AnyObservable)] {
            let actionType = type(of: action)
            items.filter { actionType.eq($0.0) }.forEach { $0.1.notify(actionType) }
        }
        if let state = state, let items = observables[.state] as? [(State.Type, AnyObservable)] {
            items.filter { $0.0 == type(of: state) }.forEach { $0.1.notify((state, payload)) }
        }
        if case .default = storeType {
            Store.default.middlewares.forEach { $0(action, payload, self) }
        }
    }
    
    public func register(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    public func state<S: State>() -> S {
        states[String(describing: S.self)] as! S
    }
    
    public func subscribe<S: State>(_ completion: @escaping (S, Payload?) -> Void) -> Token {
        let observable = Observable<(S, Payload?)>(completion)
        var observables = self.observables[.state, default: []]
        observables.append((S.self, observable))
        self.observables[.state] = observables
        completion(state(), nil)
        return observable
    }
    
    public func subscribe<S: State>(_ completion: @escaping (S) -> Void) -> Token {
        let observable = Observable<(S, Payload?)> {
            completion($0.0)
        }
        var observables = self.observables[.state, default: []]
        observables.append((S.self, observable))
        self.observables[.state] = observables
        completion(state())
        return observable
    }
    
    public func subscribe(of type: ActionType.Type..., completion: @escaping (ActionType.Type) -> Void) -> Token {
        let observable = Observable<ActionType.Type>(completion)
        var observables = self.observables[.action, default: []]
        observables.append((type, observable))
        self.observables[.action] = observables
        if OnObserve.eq(type) { completion(OnObserve.self) }
        return observable
    }
    
    public func unsubscribe(_ token: Token) {
        for (k, _) in self.observables {
            let observables = self.observables[k]!
            for i in (0..<observables.count) where observables[i].1 === token {
                self.observables[k]!.remove(at: i)
                return
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
    
    // Worker
    
    private lazy var workers: [Worker] = []

    public func cancelWork(with workerType: Worker.Type) {
        if workerType == AllWorkers.self {
            workers.removeAll()
            return
        }
        guard let index = workers.firstIndex(where: { type(of: $0) == workerType }) else { return }
        workers.remove(at: index)
    }
    
    // Dispatch
    
    public func dispatch<A: ActionType>(_ action: A) {
        switch action {
        case let action as AnyAction:
            do {
                let payload: Any?
                let state: State
                switch try action._reduce(store: self) {
                case let result as AnyResult:
                    payload = result.anyPayload
                    state = result.anyState
                case let s:
                    payload = nil
                    state = s
                }
                update(state: state)
                notify(action: action, payload: payload, state: state)
            } catch {
                notify(action: ErrorAction<A>(error: error))
            }
        case let action as AsyncAction:
            action.execute(store: self)
            notify(action: action)
        case let worker as Worker:
            worker.run(store: self)
            if let index = workers.firstIndex(where: { type(of: $0) == A.self }) {
                workers.remove(at: index)
            }
            workers.append(worker)
            notify(action: action)
        default:
            notify(action: action)
        }
    }
    
    // Remove
    
    public func removeAll() {
        states.removeAll()
        middlewares.removeAll()
        workers.removeAll()
    }
    
    public func removeObservables() {
        observables.removeAll()
    }
}
