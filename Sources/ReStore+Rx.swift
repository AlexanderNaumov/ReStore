import RxSwift

public extension Store {
    func state<S: State>() -> RxSwift.Observable<S> {
        return RxSwift.Observable.create { [weak self] observer -> Disposable in
            guard let self = self else { return Disposables.create() }
            let token = self.subscribe { (state: S) in
                observer.on(.next(state))
            }
            return Disposables.create {
                self.unsubscribe(token)
            }
        }
    }
    
    func state<S: State>() -> RxSwift.Observable<(state: S, payload: Payload)> {
        return RxSwift.Observable.create { [weak self] observer -> Disposable in
            guard let self = self else { return Disposables.create() }
            let token = self.subscribe { (state: S, payload: Payload) in
                observer.on(.next((state, payload)))
            }
            return Disposables.create {
                self.unsubscribe(token)
            }
        }
    }
    
    func didChange(of action: ActionType.Type...) -> RxSwift.Observable<ActionType.Type> {
        return RxSwift.Observable.create { [weak self] observer -> Disposable in
            guard let self = self else { return Disposables.create() }
            let token = self.subscribe(of: action as [ActionType.Type]) { type in
                observer.on(.next(type))
            }
            return Disposables.create {
                self.unsubscribe(token)
            }
        }
    }
    
    func dispatch<A: ActionType>() -> Binder<A> {
        return Binder(self) { `self`, action in
            self.dispatch(action)
        }
    }
}
