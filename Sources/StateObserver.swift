//
//  Observer.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//


protocol StateObserverType: class {
    var type: State.Type { get }
    func notify(event: AnyEvent)
}

final class StateObserver<S: State>: StateObserverType {
    private let callback: ((Event<S>) -> Void)
    
    let type: State.Type = S.self
       
    init(_ callback: @escaping (Event<S>) -> Void) {
        self.callback = callback
    }
    
    func notify(event: AnyEvent) {
        callback(Event<S>(state: event.state as! S, payload: event.payload))
    }
}
