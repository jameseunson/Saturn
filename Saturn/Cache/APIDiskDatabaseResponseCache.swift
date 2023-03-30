//
//  APIDiskDatabaseResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 27/3/2023.
//

import Foundation

final class APIDiskDatabaseResponseCache: APIDiskResponseCaching {
    func store(id: String, value: APIMemoryResponseCacheValue) throws {
        // TODO:
    }
    
    func retrieve(id: String, type: APIDiskResponseCacheType) throws -> APIMemoryResponseCacheValue {
        throw APIDiskResponseCacheError.responseDoesNotExist
    }
    
    func loadAll() -> [String : APIMemoryResponseCacheItem] {
        return [:]
    }
    
    func clearCache() throws {
        // TODO: 
    }
}
