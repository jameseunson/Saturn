//
//  APIDiskResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//
import Foundation

final class APIDiskResponseCache {
    let fm = FileManager.default
    private let queue = DispatchQueue(label: "APIDiskResponseCache")
    
    func store(id: Int, value: Any) throws {
        let url = try self.urlForPath(id)

        if self.fm.fileExists(atPath: url.path) {
            try self.fm.removeItem(atPath: url.path)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: value)
        FileManager.default.createFile(atPath: url.path, contents: jsonData)
    }
    
    func retrieve(id: Int) throws -> Any {
        let url = try urlForPath(id)
        
        if !fm.fileExists(atPath: url.path) {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        guard let data = fm.contents(atPath: url.path) else {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        return try JSONSerialization.jsonObject(with: data)
    }
    
    func loadAll() -> [Int: APIMemoryResponseCacheItem] {
        do {
            let cacheDirURL = try urlForCacheDirectory()
            let cacheItems = try fm.contentsOfDirectory(at: cacheDirURL, includingPropertiesForKeys: nil)
            var cache = [Int: APIMemoryResponseCacheItem]()
            
            for url in cacheItems {
                if let filename = url.absoluteString.components(separatedBy: CharacterSet(arrayLiteral: "/")).last,
                let filenameId = Int(filename) {
                    if let data = fm.contents(atPath: url.path) {
                        let attributes = try fm.attributesOfItem(atPath: url.path)
                        let creationDate = attributes[.creationDate] as? Date
                        
                        let obj = try JSONSerialization.jsonObject(with: data)
                        cache[filenameId] = APIMemoryResponseCacheItem(value: obj, timestamp: creationDate ?? Date.distantPast)
                        
                    } else {
                        throw APIDiskResponseCacheError.responseDoesNotExist
                    }
                }
            }
            
            return cache
            
        } catch {
            return [:]
        }
    }
    
    // MARK: -
    private func urlForPath(_ id: Int) throws -> URL {
        let cacheKey = String(id)
        return try urlForCacheDirectory().appendingPathComponent(cacheKey)
    }
    
    private func urlForCacheDirectory() throws -> URL {
        let paths = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectory = paths[0].appendingPathComponent("HNCache/")
        
        if !self.fm.fileExists(atPath: cachesDirectory.path()) {
            try self.fm.createDirectory(at: cachesDirectory, withIntermediateDirectories: false)
        }
        
        return cachesDirectory
    }
}

enum APIDiskResponseCacheError: Error {
    case responseDoesNotExist
}
