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
        stateType: State.Type?,
        execute: (Provider?, StoreAction, Any, State?) -> Void
    )
    typealias MutatorContainer = (
        stateType: State.Type,
        valueType: Any.Type?,
        commit: (Any, inout State) throws -> Any?
    )
    
    var executor: ExecutorContainer?
    var mutator: MutatorContainer?
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
        self.executor = (P.self, S.self, { p, _, _, s in executor(p as! P, s as! S) })
        return self
    }
    @discardableResult
    public func executor(_ executor: @escaping (StoreAction, Self) -> Void) -> Self {
        self.executor = (nil, nil, { _, s, a, _ in executor(s, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (StoreAction, S) -> Void) -> Self {
        self.executor = (nil, S.self, { _, sa, _, st in executor(sa, st as! S) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (Self, S) -> Void) -> Self {
        self.executor = (nil, S.self, { _, _, a, st in executor(a as! Self, st as! S) })
        return self
    }
    
    @discardableResult
    public func executor<P: Provider>(_ executor: @escaping (P, StoreAction, Self) -> Void) -> Self {
        self.executor = (P.self, nil, { p, s, a, _ in executor(p as! P, s, a as! Self) })
        return self
    }
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, Self, S) -> Void) -> Self {
        self.executor = (P.self, S.self, { p, _, a, s in executor(p as! P, a as! Self, s as! S) })
        return self
    }
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, StoreAction, S) -> Void) -> Self {
        self.executor = (P.self, S.self, { p, sa, _, st in executor(p as! P, sa, st as! S) })
        return self
    }
    @discardableResult
    public func executor<S: State>(_ executor: @escaping (StoreAction, Self, S) -> Void) -> Self {
        self.executor = (nil, S.self, { _, sa, a, st in executor(sa, a as! Self, st as! S) })
        return self
    }
    
    @discardableResult
    public func executor<P: Provider, S: State>(_ executor: @escaping (P, StoreAction, Self, S) -> Void) -> Self {
        self.executor = (P.self, S.self, { p, sa, a, st in executor(p as! P, sa, a as! Self, st as! S) })
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
