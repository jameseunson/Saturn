//
//  APIMemoryResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation
import os

protocol APIMemoryResponseCaching: AnyObject {
    func set(value: APIMemoryResponseCacheValue, for key: String)
    func get(for key: String) -> APIMemoryResponseCacheItem?
}

final class APIMemoryResponseCache: APIMemoryResponseCaching {
    var cache = [String: APIMemoryResponseCacheItem]()
    static let `default` = APIMemoryResponseCache()
    let diskCache = APIDiskResponseCache()
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    private let queue = DispatchQueue(label: "APIMemoryResponseCache")
    
    init() {
        queue.async { [weak self] in
            guard let self else { return }
            
            let start = CFAbsoluteTimeGetCurrent()
            self.cache = self.diskCache.loadAll()
            
            let diff = CFAbsoluteTimeGetCurrent() - start
            if self.isDebugLoggingEnabled { print("disk cache load complete, took \(diff) seconds") }
        }
    }
    
    func set(value: APIMemoryResponseCacheValue, for key: String) {
        queue.sync {
            cache[key] = APIMemoryResponseCacheItem(value: value, timestamp: Date())
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
    
    func get(for key: String) -> APIMemoryResponseCacheItem? {
        queue.sync {
            return cache[key]
        }
    }
}

struct APIMemoryResponseCacheItem {
    let value: APIMemoryResponseCacheValue
    let timestamp: Date
    
    func isValid(cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> Bool {
        switch cacheBehavior {
        case .`default`:
            return timestamp >= Date().addingTimeInterval(-(60*10))
        case .ignore:
            return false
        case .offlineOnly:
            return true
        }
    }
}

enum APIMemoryResponseCacheValue {
    case json(Any)
    case data(Data)
}

enum APIMemoryResponseCacheBehavior {
    /// Ignores any cache more than 10 minutes old
    case `default`
    
    /// Ignores cache, even if still valid, always hits network
    case ignore
    
    /// Uses any cache regardless of expiry
    case offlineOnly
}
