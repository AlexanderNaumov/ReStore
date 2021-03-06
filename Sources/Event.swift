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

public enum InnerEvent: Event {
    case onObserve
    case cancelTask
    case error
}

public enum Either<E1, E2> {
    case e1(E1, Any?)
    case e2(E2, Any?)
}

public func ~=<E: Event>(pattern: E, value: EitherEvent<E>) -> Bool {
    if case let .e1(val, _) = value {
        return pattern == val
    }
    return false
}

public func ~=<E: Event>(pattern: InnerEvent, value: EitherEvent<E>) -> Bool {
    if case let .e2(val, _) = value {
        return pattern == val
    }
    return false
}

public typealias AnyEitherEvent = Either<AnyEvent, InnerEvent>
public typealias EitherEvent<E> = Either<E, InnerEvent>

extension Either where E1: Event, E2: Event {
    public func eq(_ e: E1...) -> Bool {
        if case let .e1(val, _) = self {
            for e in e where e == val {
                return true
            }
        }
        return false
    }
    public func eq(_ e: E2...) -> Bool {
        if case let .e2(val, _) = self {
            for e in e where e == val {
                return true
            }
        }
        return false
    }
    
    public var payload: Any? {
        switch self {
        case let .e1(_, payload), let .e2(_, payload):
            return payload
        }
    }
}
