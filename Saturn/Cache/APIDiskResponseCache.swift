//
//  APIDiskResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//
import Foundation

final class APIDiskResponseCache {
    let fm: FileManaging
    private let queue = DispatchQueue(label: "APIDiskResponseCache")
    
    init(fileManager: FileManaging = FileManager.default) {
        self.fm = fileManager
    }
    
    func store(id: String, value: Any) throws {
        let url = try self.urlForPath(id)

        if self.fm.fileExists(atPath: url.path) {
            try self.fm.removeItem(atPath: url.path)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: value)
        if !fm.createFile(atPath: url.path, contents: jsonData, attributes: nil) {
            throw APIDiskResponseCacheError.generic
        }
    }
    
    func retrieve(id: String) throws -> Any {
        let url = try urlForPath(id)
        
        if !fm.fileExists(atPath: url.path) {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        guard let data = fm.contents(atPath: url.path) else {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        return try JSONSerialization.jsonObject(with: data)
    }
    
    func loadAll() -> [String: APIMemoryResponseCacheItem] {
        do {
            let cacheDirURL = try urlForCacheDirectory()
            let cacheItems = try fm.contentsOfDirectory(at: cacheDirURL, includingPropertiesForKeys: nil, options: [])
            var cache = [String: APIMemoryResponseCacheItem]()
            let diskCacheExpiry = diskCacheExpiry()
            
            for url in cacheItems {
                if let filename = url.absoluteString.components(separatedBy: CharacterSet(arrayLiteral: "/")).last {
                    if let data = fm.contents(atPath: url.path) {
                        let attributes = try fm.attributesOfItem(atPath: url.path)
                        let creationDate = attributes[.creationDate] as? Date
                        if let diskCacheExpiry,
                           let creationDate,
                           creationDate < diskCacheExpiry {
                            print("delete expired disk cache for \(filename)")
                            try? fm.removeItem(atPath: url.path)
                            continue
                        }
                        
                        let obj = try JSONSerialization.jsonObject(with: data)
                        cache[filename] = APIMemoryResponseCacheItem(value: obj, timestamp: creationDate ?? Date.distantPast)
                        
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
    private func diskCacheExpiry() -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -7, to: Date())
    }
    
    private func urlForPath(_ id: String) throws -> URL {
        let cacheKey = String(id)
        return try urlForCacheDirectory().appendingPathComponent(cacheKey)
    }
    
    private func urlForCacheDirectory() throws -> URL {
        let paths = fm.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectory = paths[0].appendingPathComponent("HNCache/")
        
        if !self.fm.fileExists(atPath: cachesDirectory.path()) {
            try self.fm.createDirectory(at: cachesDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        
        return cachesDirectory
    }
}

enum APIDiskResponseCacheError: Error {
    case responseDoesNotExist
    case generic
}

protocol FileManaging: AnyObject {
    func fileExists(atPath path: String) -> Bool
    func removeItem(atPath path: String) throws
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool
    func contents(atPath path: String) -> Data?
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any]
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
}

extension FileManager: FileManaging {}
