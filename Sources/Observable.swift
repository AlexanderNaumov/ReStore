//
//  Observable.swift
//  ReStore
//
//  Created by Alexander Naumov on 29.03.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

enum ObservableType {
    case action
    case state
}

public protocol Token: AnyObject {}

protocol AnyObservable: Token {
    func notify(_ value: Any)
}

final class Observable<T>: Token, AnyObservable {
    private let callback: (T) -> Void
    
    public init(_ callback: @escaping (T) -> Void) {
        self.callback = callback
    }
    
    func notify(_ value: Any) {
        callback(value as! T)
    }
}
