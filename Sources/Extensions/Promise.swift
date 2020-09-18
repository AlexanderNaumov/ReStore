//
//  Promise.swift
// 
//
//  Created by Alexander Naumov on 03.09.2018.
//  Copyright © 2018 Alexander Naumov. All rights reserved.
//

import When

public protocol AnyPromise: AnyObject {
    func cancel()
}

extension Promise: AnyPromise {}
