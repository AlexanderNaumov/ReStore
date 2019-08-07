//
//  Routing.swift
//  ReStoreRouter
//
//  Created by Alexander Naumov on 06/11/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import UIKit
import ReStore

public struct Routing {
    public enum Tag {
        case custom(Int)
        public var value: Int {
            switch self {
            case let .custom(custom):
                return custom
            }
        }
    }
    
    typealias Open = (_ from: UIViewController, _ to: UIViewController, _ sourceTag: Tag?, _ completion: @escaping () -> Void) -> Void
    public typealias OpenType = (_ from: UIViewController, _ to: UIViewController, _ sourceTag: Tag?, _ completion: @escaping () -> Void) -> Void
    public typealias OpenType2 = (_ from: UIViewController, _ to: UIViewController, _ completion: @escaping () -> Void) -> Void
    public typealias CloseType = (_ vc: UIViewController, _ completion: @escaping () -> Void) -> Void
    
    let open: Open
    let close: CloseType?
    let event: AnyEvent
    let controller: (Any?) -> UIViewController
    
    public init<T>(_ controller: @escaping (T) -> UIViewController, open: @escaping OpenType, close: CloseType? = nil, event: AnyEvent) {
        self.controller = { controller($0 as! T) }
        self.open = open
        self.close = close
        self.event = event
    }
    public init(_ controller: @escaping () -> UIViewController, open: @escaping OpenType, close: CloseType? = nil, event: AnyEvent) {
        self.controller = { _ in controller() }
        self.open = open
        self.close = close
        self.event = event
    }
    
    public init<T>(_ controller: @escaping (T) -> UIViewController, open: @escaping OpenType2, close: CloseType? = nil, event: AnyEvent) {
        self.controller = { controller($0 as! T) }
        self.open = {
            open($0, $1, $3)
        }
        self.close = close
        self.event = event
    }
    public init(_ controller: @escaping () -> UIViewController, open: @escaping OpenType2, close: CloseType? = nil, event: AnyEvent) {
        self.controller = { _ in controller() }
        self.open = {
            open($0, $1, $3)
        }
        self.close = close
        self.event = event
    }
    
    ///
    
    public init(_ configure: @escaping (UIViewController) -> Void, open: @escaping OpenType2, close: CloseType? = nil, event: AnyEvent) {
        self.controller = { _ in
            let vc = UIViewController()
            configure(vc)
            return vc
        }
        self.open = {
            open($0, $1, $3)
        }
        self.close = close
        self.event = event
    }
    public init<T>(_ configure: @escaping (UIViewController, T) -> Void, open: @escaping OpenType2, close: CloseType? = nil, event: AnyEvent) {
        self.controller = {
            let vc = UIViewController()
            configure(vc, $0 as! T)
            return vc
        }
        self.open = {
            open($0, $1, $3)
        }
        self.close = close
        self.event = event
    }
}
