//
//  APIManager.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import Combine
import Foundation
import FirebaseCore
import Firebase
import FirebaseDatabase
import SwiftUI

/// @mockable
protocol APIManaging: AnyObject {
    func loadStories(ids: [Int], cacheBehavior: CacheBehavior) -> AnyPublisher<[APIResponse<Story>], Error>
    func loadStories(ids: [Int], cacheBehavior: CacheBehavior) async throws -> APIResponse<[Story]>
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<Array<Int>>, Error>
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior) async throws -> APIResponse<Array<Int>>
    func loadStory(id: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<Story>, Error>
    func loadStory(id: Int, cacheBehavior: CacheBehavior) async throws -> APIResponse<Story>
    func loadComment(id: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<Saturn.Comment>, Error>
    func loadComment(id: Int, cacheBehavior: CacheBehavior) async throws -> APIResponse<Saturn.Comment>
    func loadUserItem(id: Int) -> AnyPublisher<UserItem, Error>
    func loadUserItem(id: Int) async throws -> UserItem
    func loadUserItems(ids: [Int]) -> AnyPublisher<[UserItem], Error>
    func loadUserItems(ids: [Int]) async throws -> [UserItem]
    func loadUser(id: String) -> AnyPublisher<User, Error>
    func getImage(for story: StoryRowViewModel) async throws -> Image
    func hasCachedResponse(for id: Int) -> Bool
}

final class APIManager: APIManaging {
    private let ref: DatabaseReferencing
    private let cache: APIMemoryResponseCaching
    private let timeoutSeconds: Int
    private let networkConnectivityManager: NetworkConnectivityManaging
    private let decoder: APIDecoder
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    init(cache: APIMemoryResponseCaching = APIMemoryResponseCache.default,
         ref: DatabaseReferencing = Database.database(url: "https://hacker-news.firebaseio.com").reference(),
         timeoutSeconds: Int = 15,
         networkConnectivityManager: NetworkConnectivityManaging = NetworkConnectivityManager.instance,
         decoder: APIDecoder = APIDecoder()) {
        self.cache = cache
        self.ref = ref
        self.timeoutSeconds = timeoutSeconds
        self.networkConnectivityManager = networkConnectivityManager
        self.decoder = decoder
    }

    func loadStories(ids: [Int], cacheBehavior: CacheBehavior = .default) -> AnyPublisher<[APIResponse<Story>], Error> {
        let stories = ids.map { return self.loadStory(id: $0, cacheBehavior: cacheBehavior) }
        return Publishers.MergeMany(stories)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func loadStories(ids: [Int], cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<[Story]> {
        return try await withThrowingTaskGroup(of: APIResponse<Story>.self, body: { group in
            for id in ids {
                group.addTask {
                    return try await self.loadStory(id: id, cacheBehavior: cacheBehavior)
                }
            }
            var stories = [APIResponse<Story>]()
            for try await story in group {
                stories.append(story)
            }
            
            let storiesArray = stories
                .reduce([Story]()) { $0 + [$1.response] }
            var source: APIResponseLoadSource = .network
            stories.forEach { if  $0.source == .cache { source = .cache } }
            
            return APIResponse(response: storiesArray, source: source)
        })
    }
    
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Array<Int>>, Error> {
        if cacheBehavior == .offlineOnly,
           cache.get(for: type.cacheKey) == nil {
            return Just(APIResponse(response: [], source: .cache))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior) {
            return Just(response)
                .tryMap { response in
                    guard case let .json(value) = response.value,
                        let ids = value as? Array<Int> else {
                        throw APIManagerError.generic
                    }
                    return APIResponse(response: ids, source: .cache)
                }
                .eraseToAnyPublisher()
            
        } else {
            return retrieve(from: type.path)
                .tryMap { response in
                    guard let ids = response as? Array<Int> else {
                        throw APIManagerError.generic
                    }
                    return APIResponse(response: ids, source: .network)
                }
                .handleEvents(receiveOutput: { ids in
                    APIMemoryResponseCache.default.set(value: .json(ids.response),
                                                       for: type.cacheKey)
                })
                .eraseToAnyPublisher()
        }
    }
    
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Array<Int>> {
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(value) = response.value,
            let responseArray = value as? Array<Int> {
            return APIResponse(response: responseArray, source: .cache)
            
        } else if let response = try await retrieve(from: type.path) as? Array<Int> {
            let apiResponse = APIResponse(response: response, source: .network)
            APIMemoryResponseCache.default.set(value: .json(apiResponse.response),
                                               for: type.cacheKey)
            return apiResponse
            
        } else {
            throw APIManagerError.generic
        }
    }
    
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Story>, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Story> {
        return try await retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Saturn.Comment>, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Saturn.Comment> {
        return try await retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadUserItem(id: Int) -> AnyPublisher<UserItem, Error> {
        retrieve(from: "v0/item/\(id)")
            .tryMap { response -> (Int, String) in
                guard let dict = response as? Dictionary<String, Any>,
                      let type = dict["type"] as? String,
                      let id = dict["id"] as? Int else {
                    throw APIManagerError.generic
                }
                return (id, type)
            }
            .flatMap { id, type -> AnyPublisher<UserItem, Error> in
                if type == "story" || type == "poll" {
                    return self.loadStory(id: id)
                        .catch { _ in
                            return Empty().eraseToAnyPublisher()
                        }
                        .map { UserItem.story($0.response) }
                        .eraseToAnyPublisher()
                    
                } else if type == "comment" {
                    return self.loadComment(id: id)
                        .flatMap { comment in
                            comment.response.loadMarkdown()
                        }
                        .catch { _ in
                            return Empty().eraseToAnyPublisher()
                        }
                        .map { UserItem.comment($0) }
                        .eraseToAnyPublisher()
                    
                } else {
                    print("APIManager, loadUserItem. ERROR: Unhandled type '\(type)'")
                    // TODO: Handle other types
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func loadUserItem(id: Int) async throws -> UserItem {
        let response = try await retrieve(from: "v0/item/\(id)")
        
        guard let dict = response as? Dictionary<String, Any>,
              let type = dict["type"] as? String,
              let id = dict["id"] as? Int else {
            throw APIManagerError.generic
        }
        if type == "story" {
            let story = try await self.loadStory(id: id)
            return UserItem.story(story.response)
            
        } else if type == "comment" {
            let comment = try await self.loadComment(id: id)
            await comment.response.loadMarkdown()
            
            return UserItem.comment(comment.response)

        } else {
            print("APIManager, loadUserItem. ERROR: Unhandled type '\(type)'")
            throw APIManagerError.generic
        }
    }
    
    func loadUserItems(ids: [Int]) -> AnyPublisher<[UserItem], Error> {
        let userItems = ids.map { return self.loadUserItem(id: $0) }
        return Publishers.MergeMany(userItems)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func loadUserItems(ids: [Int]) async throws -> [UserItem] {
        return try await withThrowingTaskGroup(of: UserItem.self, body: { group in
            for id in ids {
                group.addTask {
                    return try await self.loadUserItem(id: id)
                }
            }
            var userItems = [UserItem]()
            for try await userItem in group {
                userItems.append(userItem)
            }
            
            return userItems
        })
    }
    
    func loadUser(id: String) -> AnyPublisher<User, Error> {
        return retrieve(from: "v0/user/\(id)")
            .flatMap { response in
                return self.decoder.decodeResponse(response)
            }
            .eraseToAnyPublisher()
    }
    
    func getImage(for story: StoryRowViewModel) async throws -> Image {
        return try await loadImage(for: story, cacheBehavior: .offlineOnly)
    }
    
    func hasCachedResponse(for id: Int) -> Bool {
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: .offlineOnly) {
            return true
        }
        return false
    }
    
    // MARK: -
    private func loadImage(for story: StoryRowViewModel, cacheBehavior: CacheBehavior = .default) async throws -> Image {
        guard let imageURL = story.imageURL else {
            throw APIManagerError.generic
        }
  
        let cacheKey = imageURL.cacheKey
        
        if let response = cache.get(for: cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .data(data) = response.value,
           let image = UIImage(data: data) {
            
            return Image(uiImage: image)
        }
        
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: imageURL))
        guard let image = UIImage(data: data) else {
            throw APIManagerError.generic
        }
        
        self.cache.set(value: .data(data), for: cacheKey)
        return Image(uiImage: image)
    }
    
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<T>, Error> {
        let cacheBehaviorForConnectivity = networkConnectivityManager.isConnected() ? cacheBehavior : .offlineOnly
        
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehaviorForConnectivity),
           case let .json(value) = response.value {
            return Just(response)
                .handleEvents(receiveOutput: { _ in
                    if self.isDebugLoggingEnabled { print("cache hit: \(id)") }
                })
                .flatMap { response in
                    return self.decoder.decodeResponse(value)
                }
                .compactMap { APIResponse<T>(response: $0, source: .cache) }
                .eraseToAnyPublisher()
            
        } else {
            if isDebugLoggingEnabled { print("cache miss: \(id)") }
            return retrieve(from: "v0/item/\(id)")
                .handleEvents(receiveOutput: { response in
                    self.cache.set(value: .json(response), for: String(id))
                })
                .flatMap { response in
                    self.decoder.decodeResponse(response)
                }
                .compactMap { $0 }
                .map { APIResponse<T>(response: $0, source: .network) }
                .eraseToAnyPublisher()
        }
    }
    
    private func retrieve(from url: String) -> AnyPublisher<Any, Error> {
        return Future { [weak self] promise in
            guard let self else { return }
            
            Task {
                do {
                    let output = try await self.retrieve(from: url)
                    self.networkConnectivityManager.updateConnected(with: true)
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<T> {
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(value) = response.value {
            if isDebugLoggingEnabled { print("cache hit (async): \(id)") }
            
            let decodedResponse: T = try self.decoder.decodeResponse(value)
            return APIResponse<T>(response: decodedResponse, source: .cache)
            
        } else {
            if isDebugLoggingEnabled { print("cache miss (async): \(id)") }
            let response = try await retrieve(from: "v0/item/\(id)")
            self.cache.set(value: .json(response), for: String(id))
            
            let decodedResponse: T = try self.decoder.decodeResponse(response)
            return APIResponse<T>(response: decodedResponse, source: .network)
        }
    }
    
    private func retrieve(from url: String) async throws -> Any {
        let didComplete = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        let lock = UnfairLock()
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(self.timeoutSeconds)) {
                lock.lock {
                    if didComplete.pointee { return }; didComplete.pointee = true
                    continuation.resume(throwing: TimeoutError())
                }
            }
            
            self.ref.childPath(url).getChildData { error, snapshot in
                guard error == nil,
                      let value = snapshot?.value else {
                    
                    if let error {
                        if error.localizedDescription.contains("offline"),
                           self.networkConnectivityManager.isConnected() {
                            self.networkConnectivityManager.updateConnected(with: false)
                        }
                        lock.lock {
                            if didComplete.pointee { return }; didComplete.pointee = true
                            continuation.resume(throwing: error)
                        }
                        
                    } else {
                        lock.lock {
                            if didComplete.pointee { return }; didComplete.pointee = true
                            continuation.resume(throwing: APIManagerError.generic)
                        }
                    }
                    return
                }
                
                lock.lock {
                    if didComplete.pointee { return }; didComplete.pointee = true
                    continuation.resume(with: .success(value))
                }
            }
        }
    }
}

enum APIManagerError: Error {
    case generic
    case deleted
    case noData
}

struct APIResponse<T>: Codable where T: Codable {
    let response: T
    let source: APIResponseLoadSource
}

enum APIResponseLoadSource: Codable {
    case network
    case cache
}

public struct TimeoutError: LocalizedError {
    public var errorDescription: String? = "Task timed out before completion"
}

/// @mockable
protocol DatabaseReferencing: AnyObject {
    func childPath(_ pathString: String) -> DatabaseReferencing
    func getChildData(completion block: @escaping (Error?, DataShapshotting?) -> Void)
}

/// @mockable
protocol DataShapshotting: AnyObject {
    var value: Any? { get }
}

extension DataSnapshot: DataShapshotting {}

extension DatabaseReference: DatabaseReferencing {
    func childPath(_ pathString: String) -> DatabaseReferencing {
        child(pathString)
    }
    
    func getChildData(completion block: @escaping (Error?, DataShapshotting?) -> Void) {
        getData(completion: block)
    }
}

/// Add `cacheBehavior` defaults to `APIManaging` protocol
extension APIManaging {
    func loadStories(ids: [Int], cacheBehavior: CacheBehavior = .default) -> AnyPublisher<[APIResponse<Story>], Error> {
        loadStories(ids: ids, cacheBehavior: cacheBehavior)
    }
    func loadStories(ids: [Int], cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<[Story]> {
        try await loadStories(ids: ids, cacheBehavior: cacheBehavior)
    }
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Array<Int>>, Error> {
        loadStoryIds(type: type, cacheBehavior: cacheBehavior)
    }
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Array<Int>> {
        try await loadStoryIds(type: type, cacheBehavior: cacheBehavior)
    }
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Story>, Error> {
        loadStory(id: id, cacheBehavior: cacheBehavior)
    }
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Story> {
        try await loadStory(id: id, cacheBehavior: cacheBehavior)
    }
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Saturn.Comment>, Error> {
        loadComment(id: id, cacheBehavior: cacheBehavior)
    }
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Saturn.Comment> {
        try await loadComment(id: id, cacheBehavior: cacheBehavior)
    }
}
