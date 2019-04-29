//
//  Notification.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

protocol AnyNotification {
    init?(event: AnyEitherEvent, state: State)
}

public struct StoreNotification<E, S>: AnyNotification {
    public let event: EitherEvent<E>
    public let state: S

    init?(event: AnyEitherEvent, state: State) {
        switch event {
        case let .e1(e, p):
            self.event = .e1(e as! E, p)
        case let .e2(e, p):
            self.event = .e2(e, p)
        }
        self.state = state as! S
    }
}

public protocol AnyStoreObserver: class {}
public protocol StoreObserver: AnyStoreObserver {
    associatedtype E = Event
    associatedtype S = State
    typealias N = StoreNotification<E, S>
    func notify(notification: N)
}

public final class Observer<E: Event, S: State>: StoreObserver {
    private var callback: ((N) -> Void)!
    
    public init(_ callback: @escaping (N) -> Void) {
        self.callback = callback
    }

    public func notify(notification: StoreNotification<E, S>) {
        switch notification.event {
        case let .e2(.onObserve, observer):
            guard let observer = observer as? Observer, observer === self else { return }
            fallthrough
        default:
            callback(notification)
        }
    }
}
