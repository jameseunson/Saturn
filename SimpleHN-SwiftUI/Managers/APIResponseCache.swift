//
//  APIResponseCache.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

final class APIResponseCache {
    let fm = FileManager.default
    
    func store(path: String, value: Any) throws {
        let url = urlForPath(path)
        
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(atPath: url.path)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: value)
        FileManager.default.createFile(atPath: url.path, contents: jsonData)
    }
    
    func retrieve(path: String) throws -> Any {
        let url = urlForPath(path)
        
        if !fm.fileExists(atPath: url.path) {
            throw APIResponseCacheError.responseDoesNotExist
        }
        guard let data = fm.contents(atPath: url.path) else {
            throw APIResponseCacheError.responseDoesNotExist
        }
        return try JSONSerialization.jsonObject(with: data)
    }
    
    func urlForPath(_ path: String) -> URL {
        // TODO: Add subdirectory to contain cached responses, create if doesn't exist
        
        let cacheKey = path.replacingOccurrences(of: "/", with: "-")
        
        let paths = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectory = paths[0]
        
        return cachesDirectory.appendingPathComponent(cacheKey)
    }
}

enum APIResponseCacheError: Error {
    case responseDoesNotExist
}
