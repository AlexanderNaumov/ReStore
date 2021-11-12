//
//  Store.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public typealias Payload = Any

public final class Store {
    
    public static let `default` = Store()
    private init() {}
    
    private var states: [String: State] = [:]
    private var observables: [ObservableType: [(Any, AnyObservable)]] = [:]
    
    private func update(state: State) {
        states[String(describing: type(of: state))] = state
    }
    
    private func notify(action: ActionType, payload: Any? = nil, state: State? = nil) {
        if let state = state, let items = observables[.state] as? [(State.Type, AnyObservable)] {
            items.filter { $0.0 == type(of: state) }.forEach { $0.1.notify((state, payload)) }
        }
        if let items = observables[.action] as? [([ActionType.Type], AnyObservable)] {
            let actionType = type(of: action)
            items.filter { actionType.eq($0.0) }.forEach { $0.1.notify(actionType) }
        }
        middlewaresOld.forEach { $0(action, payload, self) }
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
        subscribe(of: type, completion: completion)
    }
    
    public func subscribe(of types: [ActionType.Type], completion: @escaping (ActionType.Type) -> Void) -> Token {
        let observable = Observable<ActionType.Type>(completion)
        var observables = self.observables[.action, default: []]
        observables.append((types, observable))
        self.observables[.action] = observables
        if OnObserve.eq(types) { completion(OnObserve.self) }
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
    
    private lazy var middlewaresOld: [StoreMiddleware] = []

    public func register(middleware: @escaping StoreMiddleware) {
        middlewaresOld.append(middleware)
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
    
    public func setState<S: State>(_ state: S) {
        update(state: state)
        if let items = observables[.state] as? [(State.Type, AnyObservable)] {
            items.filter { $0.0 == type(of: state) }.forEach { $0.1.notify((state, Payload?.none)) }
        }
    }
    
    // Remove
    
    public func removeAll() {
        states.removeAll()
        middlewaresOld.removeAll()
        workers.removeAll()
    }
    
    public func removeObservables() {
        observables.removeAll()
    }
    
    //  New
    
    private lazy var middlewares: [Middleware] = []

    public func register(middleware: @escaping Middleware) {
        middlewares.append(middleware)
    }
    
    public func dispatch(_ action: Action) {
        var next = { try action.execute() }
        
        let middlewares: [Middleware] = middlewares.reversed()
        
        for i in 0..<middlewares.count {
            next = { [next = next] in try middlewares[i](action, next) }
        }
        
        do {
            try next()
        } catch {
            print("Unhandled error: \(type(of: error)).\(error)")
        }
    }
}
