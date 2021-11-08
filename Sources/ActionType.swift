//
//  Action.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public protocol ActionType {}

extension ActionType {
    static func eq(_ actions: [ActionType.Type]) -> Bool {
        for a in actions where a == Self.self { return true }
        return false
    }
}

public protocol AnyAction: ActionType {
    func _reduce(store: Store) throws -> State
}

public protocol ActionR: AnyAction {
    associatedtype S: State
    func reduce(store: Store) throws -> S
}

public extension ActionR {
    func _reduce(store: Store) throws -> State {
        try reduce(store: store)
    }
}

public protocol AsyncAction: ActionType {
    func execute(store: Store)
}

public protocol Worker: AnyObject, ActionType {
    func run(store: Store)
}

public protocol ErrorType {
    var error: Error { get }
}

public struct ErrorAction<A: ActionType>: ErrorType, ActionType {
    public let error: Error
}

public struct OnObserve: ActionType {}

public class AllWorkers: Worker {
    public func run(store: Store) {}
}
