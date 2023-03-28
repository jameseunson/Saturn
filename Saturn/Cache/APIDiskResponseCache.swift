//
//  APIDiskResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//
import Foundation

protocol APIDiskResponseCaching: AnyObject {
    func store(id: String, value: APIMemoryResponseCacheValue) throws
    func retrieve(id: String, type: APIDiskResponseCacheType) throws -> APIMemoryResponseCacheValue
    func loadAll() -> [String: APIMemoryResponseCacheItem]
}

final class APIDiskResponseCache: APIDiskResponseCaching {
    let fm: FileManaging
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    init(fileManager: FileManaging = FileManager.default) {
        self.fm = fileManager
    }
    
    func store(id: String, value: APIMemoryResponseCacheValue) throws {
        let contents: Data
        let url: URL
        
        switch value {
        case let .json(value):
            url = try self.urlForPath(id, type: .json)
            contents = try JSONSerialization.data(withJSONObject: value)
            
        case let .data(value):
            url = try self.urlForPath(id, type: .data)
            contents = value
        }
        
        if self.fm.fileExists(atPath: url.path) {
            try self.fm.removeItem(atPath: url.path)
        }
        if !fm.createFile(atPath: url.path, contents: contents, attributes: nil) {
            throw APIDiskResponseCacheError.generic
        }
    }
    
    func retrieve(id: String, type: APIDiskResponseCacheType = .json) throws -> APIMemoryResponseCacheValue {
        let url = try urlForPath(id, type: type)
        
        if !fm.fileExists(atPath: url.path) {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        guard let data = fm.contents(atPath: url.path) else {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
        switch type {
        case .json:
            return try .json(JSONSerialization.jsonObject(with: data))
        case .data:
            return .data(data)
        }
    }
    
    func loadAll() -> [String: APIMemoryResponseCacheItem] {
        do {
            let cacheDirURL = try urlForCacheDirectory()
            let cacheItems = try fm.contentsOfDirectory(at: cacheDirURL, includingPropertiesForKeys: nil, options: [])
            var cache = [String: APIMemoryResponseCacheItem]()
            let diskCacheExpiry = diskCacheExpiry()
            
            for url in cacheItems {
                /// Extract filename, type and file contents. Supported types are listed in APIDiskResponseCacheType
                guard let filename = url.absoluteString.components(separatedBy: CharacterSet(arrayLiteral: "/")).last,
                      let filenameNoExtension = filename.components(separatedBy: ".").first,
                      let filetypeString = filename.components(separatedBy: ".").last,
                      let filetype = APIDiskResponseCacheType(rawValue: filetypeString),
                      let data = fm.contents(atPath: url.path) else {
                    continue
                }
                
                /// Check if response is outdated, delete and skip if so
                let attributes = try fm.attributesOfItem(atPath: url.path)
                let creationDate = attributes[.creationDate] as? Date
                if let diskCacheExpiry,
                   let creationDate,
                   creationDate < diskCacheExpiry {
                    if fm.fileExists(atPath: url.path) {
                        if isDebugLoggingEnabled { print("delete expired disk cache for \(filename)") }
                        try? fm.removeItem(atPath: url.path)
                    }
                    continue
                }
                
                /// Box up response as either json or data and return
                switch filetype {
                case .json:
                    let obj = try JSONSerialization.jsonObject(with: data)
                    cache[filenameNoExtension] = APIMemoryResponseCacheItem(value: .json(obj),
                                                                 timestamp: creationDate ?? Date.distantPast)
                case .data:
                    cache[filenameNoExtension] = APIMemoryResponseCacheItem(value: .data(data),
                                                                 timestamp: creationDate ?? Date.distantPast)
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
        return calendar.date(byAdding: .day, value: -30, to: Date())
    }
    
    private func urlForPath(_ id: String, type: APIDiskResponseCacheType) throws -> URL {
        let cacheKey = String(id)
        return try urlForCacheDirectory().appendingPathComponent(cacheKey).appendingPathExtension(type.rawValue)
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

enum APIDiskResponseCacheType: String {
    case json
    case data
}

/// @mockable
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
