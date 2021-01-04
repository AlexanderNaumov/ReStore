//
//  Action.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public protocol ActionType {}

extension ActionType {
    static func eq(_ action: ActionType.Type...) -> Bool {
        for a in action where a == Self.self { return true }
        return false
    }
}

public protocol Action: ActionType {
    associatedtype S: State
    func reduce(store: Store) throws -> S
}

extension Action {
    public func reduce(store: Store) throws -> EmptyState { EmptyState() }
}

public protocol AsyncAction: ActionType {
    func execute(store: Store)
}

public protocol ErrorActionType {
    var error: Error { get }
}

public struct ErrorAction<A: Action>: ErrorActionType, Action {
    public let error: Error
}

public struct OnObserve: Action {}

public struct CancelTask: Action {}
