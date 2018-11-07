//
//  Notification.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

protocol AnyNotification {
    init?(event: AnyEventResult, state: State)
}

public struct StoreNotification<E, S>: AnyNotification {
    public let event: EventResult<E>
    public let state: S

    init?(event: AnyEventResult, state: State) {
        switch event {
        case let .event(.e1(e)):
            self.event = .event(.e1(e as! E))
        case let .event(.e2(e)):
            self.event = .event(.e2(e))
        case let .error(e):
            self.event = .error(e)
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
    var removeObserver: ((Observer<E, S>) -> Void)?
    private var callback: ((N) -> Void)!
    
    public init(_ callback: @escaping (N) -> Void) {
        self.callback = callback
    }

    public func notify(notification: StoreNotification<E, S>) {
        switch notification.event {
        case let .event(.e2(.onObserve(observer))):
            guard observer === self else { return }
            fallthrough
        default:
            callback(notification)
        }
    }
}
