import Combine

extension Store {
    public struct StatePublisher<S: State>: Publisher {
        public typealias Output = S
        public typealias Failure = Never
        let store: Store
        
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
            subscriber.receive(subscription: StateSubscription(target: subscriber, store: store))
        }
    }
    
    private final class StateSubscription<Target: Subscriber, S: State>: Subscription where Target.Input == S {
        private var target: Target?
        private var token: Token?
        private weak var store: Store?
        
        init(target: Target, store: Store) {
            self.target = target
            self.store = store
            token = store.subscribe { (state: S) in
                _ = target.receive(state)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
            guard let token = token else { return }
            store?.unsubscribe(token)
        }
    }
    
    public func publisher<S: State>(_ type: S.Type? = nil) -> StatePublisher<S> {
        StatePublisher(store: self)
    }
}
