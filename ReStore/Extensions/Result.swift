//
//  Result.swift
//
//
//  Created by Alexander Naumov on 03.09.2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import When

public typealias Result = When.Result

extension Result {
    public init(_ f: @autoclosure () throws -> T) {
        do {
            self = .success(value: try f())
        } catch {
            self = .failure(error: error)
        }
    }

    public func handle() throws -> T {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }

    public func flatMap<U>(_ transform: (T) -> Result<U>) -> Result<U> {
        switch self {
        case let .success(value):
            return transform(value)
        case let .failure(error):
            return .failure(error: error)
        }
    }

    public func flatMap<U>(_ transform: (T) throws -> U) -> Result<U> {
        switch self {
        case let .success(value):
            do {
                return .success(value: try transform(value))
            } catch {
                return .failure(error: error)
            }
        case let .failure(error):
            return .failure(error: error)
        }
    }
}

postfix operator <?
postfix operator <!

public postfix func <? <T>(_ f: @autoclosure () throws -> T) -> Result<T> {
    return Result(f)
}

public postfix func <! <T>(_ r: Result<T>) throws -> T {
    return try r.handle()
}
