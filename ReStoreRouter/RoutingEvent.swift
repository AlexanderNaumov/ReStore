//
//  RoutingEvent.swift
//  ReStoreRouter
//
//  Created by Alexander Naumov on 06/11/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import ReStore

extension Routing {
    public enum Event: ReStore.Event {
        case open(AnyEvent)
        case close(AnyEvent)
    }
}

extension Routing.Event {
    public static func == (lhs: Routing.Event, rhs: Routing.Event) -> Bool {
        switch (lhs, rhs) {
        case let (.open(l), .open(r)) where l.isEqual(r),
             let (.close(l), .close(r)) where l.isEqual(r):
            return true
        default:
            return false
        }
    }
}
