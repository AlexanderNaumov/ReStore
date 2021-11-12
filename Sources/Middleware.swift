//
//  Middleware.swift
//  ReStore
//
//  Created by Alexander Naumov on 02.01.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

public typealias StoreMiddleware = (_ action: ActionType, _ payload: Any?, _ store: Store) -> Void

public typealias Middleware = (_ action: Action, _ next: () throws -> Void) throws -> Void
