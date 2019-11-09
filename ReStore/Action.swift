//
//  Action.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import When

public protocol ActionType where Self: Action {}

public class Action: ActionType {
    typealias ExecutorContainer = (
        providerType: Provider.Type?,
        execute: (Provider?, ExecutorStore, ActionType) -> Void
    )
    typealias MutatorContainer = (
        stateType: State.Type,
        valueType: Any.Type?,
        commit: (ActionType, inout State) throws -> Any?
    )
    
    typealias MutatorContainerNew = (
        stateType: State.Type,
        commit: (ActionType, MutatorStore) throws -> Mutate
    )
    
    var executor: ExecutorContainer?
    var mutator: MutatorContainer?
    var mutatorNew: MutatorContainerNew?
    let event: AnyEvent
    
    public init<E: Event>(_ event: E) {
        self.event = event
    }
}

protocol AnyActionValue: class {
    var anyValue: Any { get }
}

public typealias ActionCreator<T> = (T) -> ActionValue<T>

public class ActionValue<V>: Action {
    public let value: V
    public init<E: Event>(_ value: V, _ event: E) {
        self.value = value
        super.init(event)
    }
}

extension ActionValue: AnyActionValue {
    var anyValue: Any { return value }
}

// MARK: - Executors

extension ActionType {
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P) -> Void) -> Self {
        self.executor = (P.self, { p, _, _ in executor(p as! P) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (ExecutorStore) -> Void) -> Self {
        self.executor = (nil, { _, s, _ in executor(s) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (Self) -> Void) -> Self {
        self.executor = (nil, { _, _, a in executor(a as! Self) })
        return self
    }
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, ExecutorStore) -> Void) -> Self {
        self.executor = (P.self, { p, s, _ in executor(p as! P, s) })
        return self
    }
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, Self) -> Void) -> Self {
        self.executor = (P.self, { p, _, a in executor(p as! P, a as! Self) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (ExecutorStore, Self) -> Void) -> Self {
        self.executor = (nil, { _, s, a in executor(s, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, ExecutorStore, Self) -> Void) -> Self {
        self.executor = (P.self, { p, s, a in executor(p as! P, s, a as! Self) })
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

enum Mutate {
    case state(State)
    case result(AnyResult)
}

protocol AnyResult {
    var anyState: State { get }
    var anyPayload: Any { get }
}

public struct Result<S: State, P> {
    public let state: S, payload: P
    public init(state: S, payload: P) {
        self.state = state
        self.payload = payload
    }
}

extension Result: AnyResult {
    var anyState: State { return state }
    var anyPayload: Any { return payload }
}

extension ActionType {
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping () throws -> S) -> Self {
        self.mutatorNew = (S.self, { _, _ in
            .state(try mutator())
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (MutatorStore) throws -> S) -> Self {
        self.mutatorNew = (S.self, { _, s in
            .state(try mutator(s))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (Self) throws -> S) -> Self {
        self.mutatorNew = (S.self, { a, _ in
            .state(try mutator(a as! Self))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (Self, MutatorStore) throws -> S) -> Self {
        self.mutatorNew = (S.self, { a, s in
            .state(try mutator(a as! Self, s))
        })
        return self
    }
    
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping () throws -> Result<S, P>) -> Self {
        self.mutatorNew = (S.self, { _, _ in
            .result(try mutator())
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (MutatorStore) throws -> Result<S, P>) -> Self {
        self.mutatorNew = (S.self, { _, s in
            .result(try mutator(s))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (Self) throws -> Result<S, P>) -> Self {
        self.mutatorNew = (S.self, { a, _ in
            .result(try mutator(a as! Self))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (Self, MutatorStore) throws -> Result<S, P>) -> Self {
        self.mutatorNew = (S.self, { a, s in
            .result(try mutator(a as! Self, s))
        })
        return self
    }
}
