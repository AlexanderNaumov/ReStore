//
//  Action.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public protocol ActionType where Self: Action {}

public class Action: ActionType {
    typealias Executor = (ExecutorStore, ActionType) -> Void
    
    typealias MutatorContainer = (
        stateType: State.Type,
        commit: (ActionType, MutatorStore) throws -> Mutate
    )
    
    var executor: Executor?
    var mutator: MutatorContainer?
    let event: AnyEvent
    
    public init<E: Event>(_ event: E) {
        self.event = event
    }
}

protocol AnyActionValue: AnyObject {
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
    public func executor(_ executor: @escaping (ExecutorStore) -> Void) -> Self {
        self.executor =  { s, _ in executor(s) }
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (Self) -> Void) -> Self {
        self.executor = { _, a in executor(a as! Self) }
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (ExecutorStore, Self) -> Void) -> Self {
        self.executor = { s, a in executor(s, a as! Self) }
        return self
    }
}

// MARK: - Mutator

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
        self.mutator = (S.self, { _, _ in
            .state(try mutator())
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (MutatorStore) throws -> S) -> Self {
        self.mutator = (S.self, { _, s in
            .state(try mutator(s))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (Self) throws -> S) -> Self {
        self.mutator = (S.self, { a, _ in
            .state(try mutator(a as! Self))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State>(_ mutator: @escaping (Self, MutatorStore) throws -> S) -> Self {
        self.mutator = (S.self, { a, s in
            .state(try mutator(a as! Self, s))
        })
        return self
    }
    
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping () throws -> Result<S, P>) -> Self {
        self.mutator = (S.self, { _, _ in
            .result(try mutator())
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (MutatorStore) throws -> Result<S, P>) -> Self {
        self.mutator = (S.self, { _, s in
            .result(try mutator(s))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (Self) throws -> Result<S, P>) -> Self {
        self.mutator = (S.self, { a, _ in
            .result(try mutator(a as! Self))
        })
        return self
    }
    @discardableResult
    public func mutator<S: State, P>(_ mutator: @escaping (Self, MutatorStore) throws -> Result<S, P>) -> Self {
        self.mutator = (S.self, { a, s in
            .result(try mutator(a as! Self, s))
        })
        return self
    }
}
