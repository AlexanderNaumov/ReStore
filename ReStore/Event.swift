//
//  Event.swift
//  ReStore
//
//  Created by Alexander Naumov on 07/11/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

public protocol AnyEvent {
    func isEqual(_ e: AnyEvent) -> Bool
}
extension AnyEvent where Self: Equatable {
    public func isEqual(_ e: AnyEvent) -> Bool {
        guard let e = e as? Self else { return false }
        return self == e
    }
}
public typealias Event = AnyEvent & Equatable

public enum StoreEvent: Event {
    case onObserve(AnyStoreObserver)
    case cancelTask(TaskType)
    
    public static func == (lhs: StoreEvent, rhs: StoreEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.onObserve(o1), .onObserve(o2)):
            return o1 === o2
        case let (.cancelTask(t1), .cancelTask(t2)):
            return t1 == t2
        default:
            return false
        }
    }
}

public func ~=<E: Event>(pattern: E, value: EventResult<E>) -> Bool {
    if case let .event(.e1(val)) = value {
        return pattern == val
    }
    return false
}

public func ~=<E: Event>(pattern: StoreEvent, value: EventResult<E>) -> Bool {
    if case let .event(.e2(val)) = value {
        return pattern == val
    }
    return false
}

public enum Either<E1, E2> {
    case e1(E1)
    case e2(E2)
}

public typealias AnyEitherEvent = Either<AnyEvent, StoreEvent>
public typealias EitherEvent<E> = Either<E, StoreEvent>

public func ~=<E: Event>(pattern: E, value: EitherEvent<E>) -> Bool {
    if case let .e1(val) = value {
        return pattern == val
    }
    return false
}

public func ~=<E: Event>(pattern: StoreEvent, value: EitherEvent<E>) -> Bool {
    if case let .e2(val) = value {
        return pattern == val
    }
    return false
}

public enum AnyEventResult {
    case event(AnyEitherEvent)
    case error(Error)
}

public enum EventResult<E> {
    case event(EitherEvent<E>)
    case error(Error)
}

