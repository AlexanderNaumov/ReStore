import RxSwift

public protocol Action {
    func execute() throws
}

extension Action {
    public func state<S: State>() -> S {
        Store.default.state()
    }
    
    public func setState<S: State>(_ state: S) {
        Store.default.setState(state)
    }
    
    public func dispatch(_ action: Action) {
        Store.default.dispatch(action)
    }
    
    public func state<S: State>() -> RxSwift.Observable<S> {
        Store.default.state()
    }
}
