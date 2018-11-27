//
//  Router.swift
//
//
//  Created by Alexander Naumov.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import UIKit
import ReStore

public struct Router {
    
    private static weak var store: AnyStore?
    private static let allVC = NSHashTable<UIViewController>(options: .weakMemory)
    private let vc: UIViewController
    
    fileprivate init(_ vc: UIViewController) { self.vc = vc }
    
    public static func setStore(_ store: AnyStore) {
        self.store = store
    }
    
    public func open(_ routing: Routing, payload: Any? = nil, completion: ((Router) -> Void)? = nil) {
        Router.store?.dispatch(ActionValue<Any?>(payload, Routing.Event.open(routing.event)))
        let newVc = routing.controller(payload)
        newVc.__routing = (vc, routing.event)
        Router.allVC.add(newVc)
        routing.open(vc, newVc) { completion?(Router(newVc)) }
    }
    
    public func close(_ routing: Routing, completion: ((Router) -> Void)? = nil) {
        Router.store?.dispatch(Action(Routing.Event.close(routing.event)))
        print("-- all \(Router.allVC.allObjects)")
        for vc in Router.allVC.allObjects where vc.__routing.1.isEqual(routing.event) {
            switch true {
            case self.vc == vc:
                routing.close?(vc) { completion?(Router(vc.__routing.0)) }
                return
            case self.vc == vc.__routing.0:
                routing.close?(vc) { completion?(self) }
                return
            default:
                break
            }
        }
    }
}

extension UIViewController {
    private struct AssociatedKeys {
        static var routingContainer: UInt8 = 32
    }
    private class RoutingContainer: NSObject {
        weak var parent: UIViewController!
        let event: AnyEvent
        init(parent: UIViewController, event: AnyEvent) {
            self.parent = parent
            self.event = event
            super.init()
        }
    }
    fileprivate var __routing: (UIViewController, AnyEvent) {
        get {
            let obj = objc_getAssociatedObject(self, &AssociatedKeys.routingContainer) as! RoutingContainer
            return (obj.parent, obj.event)
        }
        set {
            let container = RoutingContainer(parent: newValue.0, event: newValue.1)
            objc_setAssociatedObject(self, &AssociatedKeys.routingContainer, container, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    public var router: Router { return Router(self) }
}
