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

extension Store {
    public func observable<E: Event, S: State>() -> Observable<(EitherEvent<E>, S)> {
        return Observable<(EitherEvent<E>, S)>.create { [weak self] observer in
            let observer = Observer333<E, S> { notificarion in
                observer.onNext((notificarion.event, notificarion.state))
            }
            self?.observe(observer)
            return Disposables.create { [weak observer] in
                guard let observer = observer else { return }
                self?.remove(observer)
            }
        }
    }
    
    public var dispatch: Binder<Action> {
        return Binder(self) { store, action in
            store.dispatch(action)
        }
    }
}

#endif
