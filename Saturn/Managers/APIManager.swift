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
import Factory

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
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior) -> AnyPublisher<UserItem, Error>
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior) async throws -> UserItem
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior) -> AnyPublisher<[UserItem], Error>
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior) async throws -> [UserItem]
    func loadUser(id: String, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<User>, Error>
    func loadUser(id: String, cacheBehavior: CacheBehavior) async throws -> APIResponse<User>
    func getImage(for story: StoryRowViewModel) async throws -> Image
    func hasCachedResponse(for id: Int) -> Bool
}

final class APIManager: APIManaging {
    private let ref: DatabaseReferencing
    private let timeoutSeconds: Int
    
    @Injected(\.apiMemoryResponseCache) private var cache
    @Injected(\.apiDecoder) private var decoder
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    init(ref: DatabaseReferencing = Database.database(url: "https://hacker-news.firebaseio.com").reference(),
         timeoutSeconds: Int = 15) {
        self.ref = ref
        self.timeoutSeconds = timeoutSeconds
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
        AsyncTools.publisherForAsync {
            try await self.loadStoryIds(type: type, cacheBehavior: cacheBehavior)
        }
    }
    
    func loadStoryIds(type: StoryListType, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Array<Int>> {
        if cacheBehavior == .offlineOnly,
           cache.get(for: type.cacheKey) == nil {
            return APIResponse(response: [], source: .cache)
        }
        
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(value) = response.value,
            let responseArray = value as? Array<Int> {
            return APIResponse(response: responseArray, source: .cache)
            
        } else if let response = try await retrieve(from: type.path) as? Array<Int> {
            let apiResponse = APIResponse(response: response, source: .network)
            self.cache.set(value: .json(apiResponse.response),
                                               for: type.cacheKey)
            return apiResponse
            
        } else {
            throw APIManagerError.generic
        }
    }
    
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Story>, Error> {
        return retrieveObject("v0/item/\(id)", cacheBehavior: cacheBehavior)
    }
    
    func loadStory(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Story> {
        return try await retrieveObject("v0/item/\(id)", cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<Saturn.Comment>, Error> {
        return retrieveObject("v0/item/\(id)", cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<Saturn.Comment> {
        return try await retrieveObject("v0/item/\(id)", cacheBehavior: cacheBehavior)
    }
    
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<UserItem, Error> {
        AsyncTools.publisherForAsync {
            try await self.loadUserItem(id: id, cacheBehavior: cacheBehavior)
        }
    }
    
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> UserItem {
        let urlString = "v0/item/\(id)"
        if let response = cache.get(for: urlString.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(value) = response.value,
           let (type, _) = try? extractUserItemKeys(response: value) {
            
            if type == "story" || type == "poll" {
                do {
                    let decodedResponse: Story = try self.decoder.decodeResponse(value)
                    return UserItem.story(decodedResponse)
                    
                } catch APIManagerError.deleted {
                    return UserItem.deleted
                }
                
            } else if type == "comment" {
                do {
                    let decodedResponse: Comment = try self.decoder.decodeResponse(value)
                    await decodedResponse.loadMarkdown()
                    return UserItem.comment(decodedResponse)
                    
                } catch APIManagerError.deleted {
                    return UserItem.deleted
                }
                
            } else {
                print("APIManager, loadUserItem. ERROR: Unhandled type '\(type)'")
                throw APIManagerNetworkError.unrecognizedItemType
            }
            
        } else {
            let response = try await retrieve(from: urlString)
            let (type, id) = try extractUserItemKeys(response: response)
            
            if type == "story" || type == "poll" {
                do {
                    let story = try await self.loadStory(id: id)
                    return UserItem.story(story.response)
                    
                } catch APIManagerError.deleted {
                    return UserItem.deleted
                }
                
            } else if type == "comment" {
                do {
                    let comment = try await self.loadComment(id: id)
                    await comment.response.loadMarkdown()
                    
                    return UserItem.comment(comment.response)
                    
                } catch APIManagerError.deleted {
                    return UserItem.deleted
                }

            } else {
                print("APIManager, loadUserItem. ERROR: Unhandled type '\(type)'")
                throw APIManagerNetworkError.unrecognizedItemType
            }
        }
    }
    
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior = .default) -> AnyPublisher<[UserItem], Error> {
        AsyncTools.publisherForAsync {
            try await self.loadUserItems(ids: ids, cacheBehavior: cacheBehavior)
        }
    }
    
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior = .default) async throws -> [UserItem] {
        return try await withThrowingTaskGroup(of: UserItem.self, body: { group in
            for id in ids {
                group.addTask {
                    return try await self.loadUserItem(id: id, cacheBehavior: cacheBehavior)
                }
            }
            var userItems = [UserItem]()
            for try await userItem in group {
                userItems.append(userItem)
            }
            
            return userItems
        })
    }
    
    func loadUser(id: String, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<User>, Error> {
        return retrieveObject("v0/user/\(id)", cacheBehavior: cacheBehavior)
    }
    
    func loadUser(id: String, cacheBehavior: CacheBehavior) async throws -> APIResponse<User> {
        return try await retrieveObject("v0/user/\(id)", cacheBehavior: cacheBehavior)
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
    
    private func retrieveObject<T: Codable>(_ url: String, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<T>, Error> {
        AsyncTools.publisherForAsync {
            try await self.retrieveObject(url, cacheBehavior: cacheBehavior)
        }
    }
    
    private func retrieveObject<T: Codable>(_ url: String, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<T> {
        let cacheBehaviorForConnectivity = networkConnectivityManager.isConnected() ? cacheBehavior : .offlineOnly
        
        if let response = cache.get(for: url.cacheKey),
           response.isValid(cacheBehavior: cacheBehaviorForConnectivity),
           case let .json(value) = response.value {
            if isDebugLoggingEnabled { print("cache hit (async): \(url)") }
            
            let decodedResponse: T = try self.decoder.decodeResponse(value)
            return APIResponse<T>(response: decodedResponse, source: .cache)
            
        } else {
            if isDebugLoggingEnabled { print("cache miss (async): \(url)") }
            let response = try await retrieve(from: url)
            self.cache.set(value: .json(response), for: url.cacheKey)
            
            let decodedResponse: T = try self.decoder.decodeResponse(response)
            return APIResponse<T>(response: decodedResponse, source: .network)
        }
    }
    
    private func retrieve(from url: String) -> AnyPublisher<Any, Error> {
        AsyncTools.publisherForAsync {
            try await self.retrieve(from: url)
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
                    continuation.resume(throwing: APIManagerNetworkError.timeout)
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
                    if !self.networkConnectivityManager.isConnected() {
                        self.networkConnectivityManager.updateConnected(with: true)
                    }
                }
            }
        }
    }
    
    private func extractUserItemKeys(response: Any) throws -> (String, Int) {
        guard let dict = response as? Dictionary<String, Any>,
              let type = dict["type"] as? String,
              let id = dict["id"] as? Int else {
            throw APIManagerError.generic
        }
        return (type, id)
    }
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
