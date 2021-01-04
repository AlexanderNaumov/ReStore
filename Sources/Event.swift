//
//  Event.swift
//  ReStore
//
//  Created by Alexander Naumov on 02.01.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

struct AnyEvent {
    let type: State.Type, state: State, payload: Any?
}

public struct Event<S: State> {
    public let state: S, payload: Any?
}
