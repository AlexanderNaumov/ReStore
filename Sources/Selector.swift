import RxSwift

@propertyWrapper
public final class Select<V: Hashable> {
    private let bag = DisposeBag()
    
    public var projectedValue: RxSwift.Observable<V> { subject }
    public var wrappedValue: V {
        get { try! subject.value() }
        set { subject.on(.next(newValue)) }
    }
    
    private let subject: BehaviorSubject<V>
    
    public convenience init<S: State>(_ keyPath: KeyPath<S, V>) {
        self.init { (state: S) in
            state[keyPath: keyPath]
        }
    }
    
    public convenience init<S: State, P>(_ f: @escaping (S) -> (P) -> V, _ p: P) {
        self.init { (state: S) in
            f(state)(p)
        }
    }
    
    public convenience init<S: State, P1, P2>(_ f: @escaping (S) -> (P1, P2) -> V, _ p1: P1, p2: P2) {
        self.init { (state: S) in
            f(state)(p1, p2)
        }
    }
    
    public convenience init<S: State, P1, P2, P3>(_ f: @escaping (S) -> (P1, P2, P3) -> V, _ p1: P1, p2: P2, p3: P3) {
        self.init { (state: S) in
            f(state)(p1, p2, p3)
        }
    }
    
    private init<S: State>(condition: @escaping (S) -> V) {
        let state: S = Store.default.state()
        subject = BehaviorSubject(value: condition(state))
        
        let state$: RxSwift.Observable<S> = Store.default.state()
        state$.withUnretained(self).compactMap { `self`, state in
            let newValue = condition(state)
            guard self.wrappedValue.hashValue != newValue.hashValue else { return nil }
            return newValue
        }.subscribe(subject).disposed(by: bag)
    }
}
