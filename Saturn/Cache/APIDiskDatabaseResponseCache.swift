//
//  APIDiskDatabaseResponseCache.swift
//  Saturn
//
//  Created by James Eunson on 27/3/2023.
//

import Foundation
import Factory
import CoreData

final class APIDiskDatabaseResponseCache: APIDiskResponseCaching {
    @Injected(\.persistenceManager) private var persistenceManager
    lazy var context: NSManagedObjectContext = persistenceManager.container.viewContext
    
    init() {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func store(id: String, value: APIMemoryResponseCacheValue) throws {
        let fetchRequest = DiskCacheItem.fetchRequest(for: id)
        if let result = try context.fetch(fetchRequest).first {
            context.delete(result)
            try context.save()
        }
        
        /// Save
        let item = DiskCacheItem(context: context)
        item.date = Date()
        item.key = id
        
        switch value {
        case let .json(value):
            item.value = try JSONSerialization.data(withJSONObject: value)
            item.type = APIDiskResponseCacheType.json.rawValue
            
        case let .data(value):
            item.value = value
            item.type = APIDiskResponseCacheType.data.rawValue
        }
        try context.save()
    }
    
    func retrieve(id: String, type: APIDiskResponseCacheType) throws -> APIMemoryResponseCacheValue {
        let fetchRequest = DiskCacheItem.fetchRequest(for: id)
        do {
            guard let result = try context.fetch(fetchRequest).first,
                  let rawType = result.type,
                  let type = APIDiskResponseCacheType(rawValue: rawType),
                  let data = result.value else {
                throw APIDiskResponseCacheError.responseDoesNotExist
            }
            
            switch type {
            case .json:
                return try .json(JSONSerialization.jsonObject(with: data))
            case .data:
                return .data(data)
            }
            
        } catch {
            throw APIDiskResponseCacheError.responseDoesNotExist
        }
    }
    
    func loadAll() -> [String : APIMemoryResponseCacheItem] {
        let fetchRequest = DiskCacheItem.fetchRequest()
        let diskCacheExpiry = diskCacheExpiry()
        var cache = [String: APIMemoryResponseCacheItem]()
        
        do {
            let cacheItems = try context.fetch(fetchRequest)
            for item in cacheItems {
                guard let creationDate = item.date else {
                    continue
                }
                if let diskCacheExpiry,
                   creationDate < diskCacheExpiry {
                    print("deleting \(String(describing: item.key))")
                    context.delete(item)
                    try context.save()
                    continue
                }
                
                guard let rawType = item.type,
                      let key = item.key,
                      let type = APIDiskResponseCacheType(rawValue: rawType),
                      let data = item.value else {
                    continue
                }
                
                /// Box up response as either json or data and return
                switch type {
                case .json:
                    let obj = try JSONSerialization.jsonObject(with: data)
                    cache[key] = APIMemoryResponseCacheItem(value: .json(obj),
                                                                 timestamp: creationDate)
                case .data:
                    cache[key] = APIMemoryResponseCacheItem(value: .data(data),
                                                                 timestamp: creationDate)
                }
            }
            
        } catch {
            return [:]
        }
        
        return cache
    }
    
    func clearCache() throws {
        let fetchRequest = DiskCacheItem.fetchRequest()
        let cacheItems = try context.fetch(fetchRequest)
        
        for item in cacheItems {
            context.delete(item)
        }
        try context.save()
    }
    
    // MARK: -
    private func diskCacheExpiry() -> Date? {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -30, to: Date())
    }
}

extension DiskCacheItem {
    static func fetchRequest(for key: String) -> NSFetchRequest<DiskCacheItem> {
        let fetchRequest = DiskCacheItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        fetchRequest.fetchLimit = 1
        return fetchRequest
    }
}
