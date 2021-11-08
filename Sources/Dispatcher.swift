
public protocol Action {
    func execute() throws
}

public typealias Middleware = (_ action: Action, _ next: () throws -> Void) throws -> Void

public final class Dispatcher {
    public static let `default` = Dispatcher()
    private init() {}
    
    private lazy var middlewares: [Middleware] = []

    public func register(middleware: @escaping Middleware) {
        middlewares.append(middleware)
    }
    
    func dispatch(_ action: Action) {
        var next = { try action.execute() }
        
        let middlewares: [Middleware] = middlewares.reversed()
        
        for i in 0..<middlewares.count {
            next = { [next = next] in try middlewares[i](action, next) }
        }
        
        do {
            try next()
        } catch {
            print("Unhandled error: \(type(of: error)).\(error)")
        }
    }
}
