//
//  Store+Rx.swift
//  ReStore
//
//  Created by Alexander Naumov on 06/11/2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

#if canImport(RxSwift)

import RxSwift
import RxCocoa

extension Observer: Disposable {
    public func dispose() { removeObserver?(self) }
}

extension Store {
    public func observable<E: Event, S: State>() -> Observable<(EitherEvent<E>, S)> {
        return Observable<(EitherEvent<E>, S)>.create { observer in
            let observer = Observer<E, S> { notificarion in
                observer.onNext((notificarion.event, notificarion.state))
            }
            observer.removeObserver = { [weak self] in self?.remove($0) }
            self.observe(observer)
            return observer
        }
    }
    
    public var dispatch: Binder<Action> {
        return Binder(self) { store, action in
            store.dispatch(action)
        }
    }
}

#endif
