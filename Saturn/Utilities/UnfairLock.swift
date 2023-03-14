//
//  UnfairLock.swift
//  Saturn
//
//  Created by James Eunson on 14/3/2023.
//

import Foundation

/// https://gist.github.com/achernoprudov/6fc4ae734051630bee3a53fa171c4574
public class UnfairLock {
    // MARK: - Instance variables
    private var unfairLock = os_unfair_lock_s()

    // MARK: - Public
    public init() {}

    public func lock() {
        os_unfair_lock_lock(&unfairLock)
    }

    public func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }

    public func lock<T>(block: () throws -> T) rethrows -> T {
        lock()
        defer {
            unlock()
        }
        return try block()
    }
}
