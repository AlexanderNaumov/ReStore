//
//  StoreState.swift
//  ReStore
//
//  Created by Alexander Naumov on 28.12.2020.
//  Copyright © 2020 Alexander Naumov. All rights reserved.
//

import RxSwift

public final class StoreState<T: State>: ObservableType {
    public let value: T
    private weak var store: Store?
    init(_ store: Store, value: T) {
        self.value = value
        self.store = store
    }
    
    public typealias Element = T
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Element == Observer.Element {
        let observer = StateObserver<T> { state in
            observer.onNext(state)
        }
        store?.observe(observer)
        return Disposables.create { [weak self, weak observer] in
            guard let observer = observer else { return }
            self?.store?.remove(observer: observer)
        }
    }
}
