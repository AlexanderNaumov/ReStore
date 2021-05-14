//
//  Observers.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//


public protocol AnyEventObserver: AnyObject {}

final class EventObserver<E: Event>: AnyEventObserver {
    private var callback: ((EitherEvent<E>) -> Void)!
       
    init(_ callback: @escaping (EitherEvent<E>) -> Void) {
        self.callback = callback
    }
    
    func notify(event: AnyEitherEvent) {
        switch event {
        case let .e2(.onObserve, observer):
            guard let observer = observer as? EventObserver, observer === self else { return }
            fallthrough
        default:
            var ev: EitherEvent<E>
            switch event {
            case let .e1(e, p):
                ev = .e1(e as! E, p)
            case let .e2(e, p):
                ev = .e2(e, p)
            }
            callback(ev)
        }
    }
}

protocol AnyStateObserver: AnyObject {}

final class StateObserver<S: State>: AnyStateObserver {
    private var callback: ((S) -> Void)!
       
    init(_ callback: @escaping (S) -> Void) {
        self.callback = callback
    }
    
    func notify(state: State) {
        callback(state as! S)
    }
}
