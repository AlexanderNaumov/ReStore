//
//  JobType.swift
//  ReStore
//
//  Created by Alexander Naumov on 02.01.2021.
//  Copyright © 2021 Alexander Naumov. All rights reserved.
//

public struct JobType: RawRepresentable {
    public static let all = JobType(rawValue: "allWorkers")
    
    public var rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
