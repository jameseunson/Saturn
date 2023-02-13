//
//  APIMemoryResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation
import os

final class APIMemoryResponseCache {
    var cache = [Int: Any]()
    static let `default` = APIMemoryResponseCache()
    let diskCache = APIDiskResponseCache()
    
    private let queue = DispatchQueue(label: "APIMemoryResponseCache")
    
    init() {
        queue.async { [weak self] in
            guard let self else { return }
            
            let start = CFAbsoluteTimeGetCurrent()
            self.cache = self.diskCache.loadAll()
            
            let diff = CFAbsoluteTimeGetCurrent() - start
            print("disk cache load complete, took \(diff) seconds")
        }
    }
    
    func set(value: Any, for key: Int) {
        queue.sync {
            cache[key] = value
        }
        DispatchQueue.main.async(qos: .background) { [weak self] in
            guard let self else { return }
            do {
                try self.diskCache.store(id: key, value: value)
            } catch {
                print(error)
            }
        }
    }
    
    func get(for key: Int) -> Any? {
        queue.sync {
            return cache[key]
        }
    }
}
