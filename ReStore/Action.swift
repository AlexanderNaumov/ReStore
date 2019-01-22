//
//  Action.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import When

public typealias ActionCreator<T> = (T) -> ActionValue<T>
public typealias DispatchAction = (Action) -> Void
public typealias CancelTaskAction = (TaskType) -> Void

public protocol ActionType where Self: Action {}

public class Action: ActionType {
    typealias OldExecutorContainer = (
        stateType: State.Type?,
        execute: (AnyProvider?, @escaping DispatchAction, @escaping CancelTaskAction, Any, State?) -> Void
    )
    typealias ExecutorContainer = (
        providerType: Provider.Type?,
        stateType: State.Type?,
        execute: (Provider?, StoreAction, Any, State?) -> Void
    )
    typealias MutatorContainer = (
        stateType: State.Type,
        valueType: Any.Type?,
        commit: (Any, inout State) throws -> Any?
    )
    typealias EventContainer = (
        eventType: AnyEvent.Type,
        valueType: Any.Type?,
        event: (Any?) -> AnyEvent
    )
    typealias AnyProvider = (Any?) -> Any?
    typealias ProviderContainer = (
        type: TaskType?,
        provider: AnyProvider
    )

    var oldExecutor: OldExecutorContainer?
    var executor: ExecutorContainer?
    var mutator: MutatorContainer?
    var event: EventContainer!
    var provider: ProviderContainer?
    
    public init<E: Event>(_ event: E) {
        self.event = (E.self, nil, { _ in event })
    }
    public init<E: Event, V: Any>(_ event: @escaping (V) -> E) {
        self.event = (E.self, V.self, { v in event(v as! V) })
    }
}

protocol AnyActionValue: class {
    var anyValue: Any? { get }
}

public class ActionValue<V>: Action {
    public private(set) var value: V!
    public init<E: Event>(_ value: V, _ event: E) {
        super.init(event)
        self.value = value
    }
    public init<E: Event, EV: Any>(_ value: V, _ event: @escaping (EV) -> E) {
        super.init(event)
        self.value = value
    }
}

extension ActionValue: AnyActionValue {
    var anyValue: Any? {
        return value
    }
}

// MARK: - New Executors

extension ActionType {
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P) -> Void) -> Self {
        self.executor = (P.self, nil, { p, _, _, _ in executor(p as! P) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (StoreAction) -> Void) -> Self {
        self.executor = (nil, nil, { _, s, _, _ in executor(s) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (Self) -> Void) -> Self {
        self.executor = (nil, nil, { _, _, a, _ in executor(a as! Self) })
        return self
    }
    
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, StoreAction) -> Void) -> Self {
        self.executor = (P.self, nil, { p, s, _, _ in executor(p as! P, s) })
        return self
    }
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, Self) -> Void) -> Self {
        self.executor = (P.self, nil, { p, _, a, _ in executor(p as! P, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, S) -> Void) -> Self {
        self.executor = (P.self, nil, { p, _, _, s in executor(p as! P, s as! S) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (StoreAction, Self) -> Void) -> Self {
        self.executor = (nil, nil, { _, s, a, _ in executor(s, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (StoreAction, S) -> Void) -> Self {
        self.executor = (nil, nil, { _, sa, _, st in executor(sa, st as! S) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (Self, S) -> Void) -> Self {
        self.executor = (nil, nil, { _, _, a, st in executor(a as! Self, st as! S) })
        return self
    }
    
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, StoreAction, Self) -> Void) -> Self {
        self.executor = (P.self, nil, { p, s, a, _ in executor(p as! P, s, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, Self, S) -> Void) -> Self {
        self.executor = (P.self, nil, { p, _, a, s in executor(p as! P, a as! Self, s as! S) })
        return self
    }
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, StoreAction, S) -> Void) -> Self {
        self.executor = (P.self, nil, { p, sa, _, st in executor(p as! P, sa, st as! S) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (StoreAction, Self, S) -> Void) -> Self {
        self.executor = (nil, nil, { _, sa, a, st in executor(sa, a as! Self, st as! S) })
        return self
    }
    
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, StoreAction, Self, S) -> Void) -> Self {
        self.executor = (P.self, nil, { p, sa, a, st in executor(p as! P, sa, a as! Self, st as! S) })
        return self
    }
}

// MARK: - Mutator

extension ActionType {
    @discardableResult
    public func mutator<S: State, V: Any>(_ mutator: @escaping (inout S) throws -> V) -> Self {
        self.mutator = (S.self, V.self, { _, s in
            var state = s as! S
            defer { s = state }
            return try mutator(&state)
        })
        return self
    }
    
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (inout S) throws -> Void) -> Self {
        self.mutator = (S.self, nil, { _, s in
            var state = s as! S
            defer { s = state }
            try mutator(&state)
            return nil
        })
        return self
    }
    
    @discardableResult
    public func mutator<S: State, V: Any>(_ mutator: @escaping (Self, inout S) throws -> V) -> Self {
        self.mutator = (S.self, V.self, { a, s in
            var state = s as! S
            defer { s = state }
            return try mutator(a as! Self, &state)
        })
        return self
    }
    
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (Self, inout S) throws -> Void) -> Self {
        self.mutator = (S.self, nil, { a, s in
            var state = s as! S
            defer { s = state }
            try mutator(a as! Self, &state)
            return nil
        })
        return self
    }
}

// MARK: - Provider

extension ActionType {
    @discardableResult
    public func provider(_ provider: @escaping () -> Void, type: TaskType? = nil) -> Self {
        self.provider = (type, { _ in
            provider()
            return nil
        })
        return self
    }

    @discardableResult
    public func provider(_ provider: @escaping () -> AnyPromise, type: TaskType? = nil) -> Self {
        self.provider = (type, { _ in
            provider()
        })
        return self
    }

    @discardableResult
    public func provider(_ provider: @escaping () -> Any, type: TaskType? = nil) -> Self {
        self.provider = (type, { _ in
            provider()
        })
        return self
    }

    @discardableResult
    public func provider<V: Any>(_ provider: @escaping (V) -> Void, type: TaskType? = nil) -> Self {
        self.provider = (type, { v in
            provider(v as! V)
            return nil
        })
        return self
    }

    @discardableResult
    public func provider<V: Any>(_ provider: @escaping (V) -> AnyPromise, type: TaskType? = nil) -> Self {
        self.provider = (type, { v in
            provider(v as! V)
        })
        return self
    }
    
    @discardableResult
    public func provider<V: Any>(_ provider: @escaping (V) -> Any, type: TaskType? = nil) -> Self {
        self.provider = (type, { v in
            provider(v as! V)
        })
        return self
    }
    
}

// MARK: - Executor

public typealias ProviderE = () -> Void
public typealias ProviderR<R> = () -> R
public typealias ProviderPR<R> = () -> Promise<R>
public typealias ProviderV<V> = (V) -> Void
public typealias ProviderVR<V, R> = (V) -> R
public typealias ProviderVPR<V, R> = (V) -> Promise<R>

extension ActionType {

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, _, _ in
            executor({ _ = p!(nil) }, d)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, _, _ in
            executor({ p!(nil) as! Promise<R> }, d)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, _, _, _ in
            executor({ r!(nil) as! R }, d)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, _, _ in
            executor({ _ = p!($0) }, d)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, _, _ in
            executor({ p!($0) as! Promise<R> }, d)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, _, _, _ in
            executor({ r!($0) as! R }, d)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, _, s in
            executor({ _ = p!(nil) }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, _, s in
            executor({ p!(nil) as! Promise<R> }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, _, _, s in
            executor({ r!(nil) as! R }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, _, s in
            executor({ _ = p!($0) }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, _, s in
            executor({ p!($0) as! Promise<R> }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, _, _, s in
            executor({ r!($0) as! R }, d, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, _, _ in
            executor({ _ = p!(nil) })
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, _, _ in
            executor({ p!(nil) as! Promise<R> })
        })
        return self
    }
    
    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, _, _, _ in
            executor({ r!(nil) as! R })
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, _, _ in
            executor({ _ = p!($0) })
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, _, _ in
            executor({ p!($0) as! Promise<R> })
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, _, _, _ in
            executor({ r!($0) as! R })
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, _, s in
            executor({ _ = p!(nil) }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, _, s in
            executor({ p!(nil) as! Promise<R> }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, _, _, s in
            executor({ r!(nil) as! R }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, _, s in
            executor({ _ = p!($0) }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, _, s in
            executor({ p!($0) as! Promise<R> }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, _, _, s in
            executor({ r!($0) as! R }, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, a, _ in
            executor({ _ = p!(nil) }, d, a as! Self)
        })
        return self
    }
    
    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, a, _ in
            executor({ p!(nil) as! Promise<R> }, d, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, _, a, _ in
            executor({ r!(nil) as! R }, d, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, a, _ in
            executor({ _ = p!($0) }, d, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, _, a, _ in
            executor({ p!($0) as! Promise<R> }, d, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, _, a, _ in
            executor({ r!($0) as! R }, d, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, a, s in
            executor({ _ = p!(nil) }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, a, s in
            executor({ p!(nil) as! Promise<R> }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, _, a, s in
            executor({ r!(nil) as! R }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, a, s in
            executor({ _ = p!($0) }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, _, a, s in
            executor({ p!($0) as! Promise<R> }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, _, a, s in
            executor({ r!($0) as! R }, d, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, a, _ in
            executor({ _ = p!(nil) }, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, a, _ in
            executor({ p!(nil) as! Promise<R> }, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, _, a, _ in
            executor({ r!(nil) as! R }, a as! Self)
        })
        return self
    }
    
    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, a, _ in
            executor({ _ = p!($0) }, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, _, a, _ in
            executor({ p!($0) as! Promise<R> }, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, _, a, _ in
            executor({ r!($0) as! R }, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, a, s in
            executor({ _ = p!(nil) }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, a, s in
            executor({ p!(nil) as! Promise<R> }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, _, a, s in
            executor({ r!(nil) as! R }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, a, s in
            executor({ _ = p!($0) }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, _, a, s in
            executor({ p!($0) as! Promise<R> }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, _, a, s in
            executor({ r!($0) as! R }, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, _, _ in
            executor({ _ = p!(nil) }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, _, _ in
            executor({ p!(nil) as! Promise<R> }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, c, _, _ in
            executor({ r!(nil) as! R }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, _, _ in
            executor({ _ = p!($0) }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, _, _ in
            executor({ p!($0) as! Promise<R> }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, c, _, _ in
            executor({ r!($0) as! R }, d, c)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, _, s in
            executor({ _ = p!(nil) }, d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, _, s in
            executor({ p!(nil) as! Promise<R> }, d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, c, _, s in
            executor({ r!(nil) as! R }, d, c, s as! S)
        })
        return self
    }
    
    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, _, s in
            executor({ _ = p!($0) }, d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, _, s in
            executor({ p!($0) as! Promise<R> }, d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, c, _, s in
            executor({ r!($0) as! R }, d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, _, _ in
            executor({ _ = p!(nil) }, c)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, _, _ in
            executor({ p!(nil) as! Promise<R> }, c)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, c, _, _ in
            executor({ r!(nil) as! R }, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, _, _ in
            executor({ _ = p!($0) }, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, _, _ in
            executor({ p!($0) as! Promise<R> }, c)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, c, _, _ in
            executor({ r!($0) as! R }, c)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, _, s in
            executor({ _ = p!(nil) }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, _, s in
            executor({ p!(nil) as! Promise<R> }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, c, _, s in
            executor({ r!(nil) as! R }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, _, s in
            executor({ _ = p!($0) }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, _, s in
            executor({ p!($0) as! Promise<R> }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, c, _, s in
            executor({ r!($0) as! R }, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, a, _ in
            executor({ _ = p!(nil) }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, a, _ in
            executor({ p!(nil) as! Promise<R> }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, c, a, _ in
            executor({ r!(nil) as! R }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, a, _ in
            executor({ _ = p!($0) }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, d, c, a, _ in
            executor({ p!($0) as! Promise<R> }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, d, c, a, _ in
            executor({ r!($0) as! R }, d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, a, s in
            executor({ _ = p!(nil) }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, a, s in
            executor({ p!(nil) as! Promise<R> }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, c, a, s in
            executor({ r!(nil) as! R }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, a, s in
            executor({ _ = p!($0) }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, d, c, a, s in
            executor({ p!($0) as! Promise<R> }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, d, c, a, s in
            executor({ r!($0) as! R }, d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (ProviderE, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, a, _ in
            executor({ _ = p!(nil) }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderPR<R>, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, a, _ in
            executor({ p!(nil) as! Promise<R> }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any>(_ executor: @escaping (ProviderR<R>, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, c, a, _ in
            executor({ r!(nil) as! R }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any>(_ executor: @escaping (ProviderV<V>, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, a, _ in
            executor({ _ = p!($0) }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVPR<V, R>, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { p, _, c, a, _ in
            executor({ p!($0) as! Promise<R> }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any>(_ executor: @escaping (ProviderVR<V, R>, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { r, _, c, a, _ in
            executor({ r!($0) as! R }, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (ProviderE, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, a, s in
            executor({ _ = p!(nil) }, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderPR<R>, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, a, s in
            executor({ p!(nil) as! Promise<R> }, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<R: Any, S: State>(_ executor: @escaping (ProviderR<R>, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, c, a, s in
            executor({ r!(nil) as! R }, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, S: State>(_ executor: @escaping (ProviderV<V>, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, a, s in
            executor({ _ = p!($0) }, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVPR<V, R>, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { p, _, c, a, s in
            executor({ p!($0) as! Promise<R> }, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor<V: Any, R: Any, S: State>(_ executor: @escaping (ProviderVR<V, R>, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { r, _, c, a, s in
            executor({ r!($0) as! R }, c, a as! Self, s as! S)
        })
        return self
    }
    
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping DispatchAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, d, _, _, s in
            executor(d, s as! S)
        })
        return self
    }
    
    @discardableResult
    public func executor(_ executor: @escaping (@escaping DispatchAction) -> Void) -> Self {
        self.oldExecutor = (nil, { _, d, _, _, _ in
            executor(d)
        })
        return self
    }
    
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, _, _, _, s in
            executor(s as! S)
        })
        return self
    }
    
    @discardableResult
    public func executor(_ executor: @escaping () -> Void) -> Self {
        self.oldExecutor = (nil, { _, _, _, _, _ in
            executor()
        })
        return self
    }
    
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping DispatchAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, d, _, a, s in
            executor(d, a as! Self, s as! S)
        })
        return self
    }
    
    @discardableResult
    public func executor(_ executor: @escaping (@escaping DispatchAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { _, d, _, a, _ in
            executor(d, a as! Self)
        })
        return self
    }
    
//    @discardableResult
//    public func executor<S: State>(_ executor: @escaping (Self, S) -> Void) -> Self {
//        self.oldExecutor = (S.self, { _, _, _, a, s in
//            executor(a as! Self, s as! S)
//        })
//        return self
//    }
//
//    @discardableResult
//    public func executor(_ executor: @escaping (Self) -> Void) -> Self {
//        self.oldExecutor = (nil, { _, _, _, a, _ in
//            executor(a as! Self)
//        })
//        return self
//    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping DispatchAction, @escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, d, c, _, s in
            executor(d, c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (@escaping DispatchAction, @escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { _, d, c, _, _ in
            executor(d, c)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping CancelTaskAction, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, _, c, _, s in
            executor(c, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (@escaping CancelTaskAction) -> Void) -> Self {
        self.oldExecutor = (nil, { _, _, c, _, _ in
            executor(c)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping DispatchAction, @escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, d, c, a, s in
            executor(d, c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (@escaping DispatchAction, @escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { _, d, c, a, _ in
            executor(d, c, a as! Self)
        })
        return self
    }

    @discardableResult
    public func executor<S: State>(_ executor: @escaping (@escaping CancelTaskAction, Self, S) -> Void) -> Self {
        self.oldExecutor = (S.self, { _, _, c, a, s in
            executor(c, a as! Self, s as! S)
        })
        return self
    }

    @discardableResult
    public func executor(_ executor: @escaping (@escaping CancelTaskAction, Self) -> Void) -> Self {
        self.oldExecutor = (nil, { _, _, c, a, _ in
            executor(c, a as! Self)
        })
        return self
    }
}
