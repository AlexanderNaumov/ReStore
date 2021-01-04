//
//  State.swift
//  ReStore
//
//  Created by Alexander Naumov on 01.01.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

public protocol State {}
public struct EmptyState: State {}

public struct Result<S: State, P>: State {
    public let state: S, payload: P
}

protocol AnyResult {
    var anyState: State { get }
    var anyPayload: Any { get }
}

extension Result: AnyResult {
    var anyState: State { state }
    var anyPayload: Any { payload }
}
