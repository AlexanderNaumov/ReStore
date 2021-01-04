//
//  ActionObserver.swift
//  ReStore
//
//  Created by Alexander Naumov on 02.01.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

final class ActionObserver {
    private let callback: ((ActionType.Type) -> Void)
    let types: [ActionType.Type]
    
    init(types: [ActionType.Type], _ callback: @escaping (ActionType.Type) -> Void) {
        self.types = types
        self.callback = callback
    }
    
    func notify(type: ActionType.Type) {
        callback(type)
    }
}
