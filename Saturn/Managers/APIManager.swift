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

final class APIManager {
    let ref: DatabaseReferencing
    let cache: APIMemoryResponseCaching
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    init(cache: APIMemoryResponseCaching = APIMemoryResponseCache.default,
         ref: DatabaseReferencing = Database.database(url: "https://hacker-news.firebaseio.com").reference()) {
        self.cache = cache
        self.ref = ref
    }

    func loadStories(ids: [Int], cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<[APIResponse<Story>], Error> {
        let stories = ids.map { return self.loadStory(id: $0, cacheBehavior: cacheBehavior) }
        return Publishers.MergeMany(stories)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func loadStories(ids: [Int], cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> APIResponse<[Story]> {
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
    
    func loadStoryIds(type: StoryListType, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<APIResponse<Array<Int>>, Error> {
        if cacheBehavior == .offlineOnly,
           cache.get(for: type.cacheKey) == nil {
            return Empty()
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
    
    func loadStoryIds(type: StoryListType, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> APIResponse<Array<Int>> {
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           case let .json(value) = response.value,
            let responseArray = value as? Array<Int> {
            return APIResponse(response: responseArray, source: .cache)
            
        } else if let response = try await retrieve(from: type.path) as? Array<Int> {
            return APIResponse(response: response, source: .network)
        } else {
            throw APIManagerError.generic
        }
    }
    
    func loadStory(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<APIResponse<Story>, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadStory(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> APIResponse<Story> {
        return try await retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<APIResponse<Comment>, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> APIResponse<Comment> {
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
                return self.decodeResponse(response)
            }
            .eraseToAnyPublisher()
    }
    
    func getImage(for story: StoryRowViewModel) async throws -> Image {
        return try await loadImage(for: story, cacheBehavior: .offlineOnly)
    }
    
    // MARK: -
    private func loadImage(for story: StoryRowViewModel, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> Image {
        guard let imageURL = story.imageURL else {
            throw APIManagerError.generic
        }
  
        let cacheKey = imageURL.absoluteString
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        
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
    
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<APIResponse<T>, Error> {
        let cacheBehaviorForConnectivity = NetworkConnectivityManager.instance.isConnected() ? cacheBehavior : .offlineOnly
        
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehaviorForConnectivity),
           case let .json(value) = response.value {
            return Just(response)
                .handleEvents(receiveOutput: { _ in
                    if self.isDebugLoggingEnabled { print("cache hit: \(id)") }
                })
                .flatMap { response in
                    return self.decodeResponse(value)
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
                    self.decodeResponse(response)
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
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> APIResponse<T> {
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehavior) {
            if isDebugLoggingEnabled { print("cache hit (async): \(id)") }
            return try self.decodeResponse(response.value)
            
        } else {
            if isDebugLoggingEnabled { print("cache miss (async): \(id)") }
            let response = try await retrieve(from: "v0/item/\(id)")
            self.cache.set(value: .json(response), for: String(id))
            return try self.decodeResponse(response)
        }
    }
    
    private func retrieve(from url: String) async throws -> Any {
        let didTimeout = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        let didComplete = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(15)) {
                if didComplete.pointee { return }
                didTimeout.pointee = true

                continuation.resume(throwing: TimeoutError())
            }
            self.ref.childPath(url).getChildData { error, snapshot in
                guard error == nil,
                      let value = snapshot?.value else {
                    
                    if let error {
                        if didTimeout.pointee { return }
                        didComplete.pointee = true
                        
                        if error.localizedDescription.contains("offline"),
                           NetworkConnectivityManager.instance.isConnected() {
                            NetworkConnectivityManager.instance.updateConnected(with: false)
                        }
                        continuation.resume(throwing: error)
                        
                    } else {
                        if didTimeout.pointee { return }
                        didComplete.pointee = true
                        
                        continuation.resume(throwing: APIManagerError.generic)
                    }
                    return
                }
                
                if didTimeout.pointee { return }
                didComplete.pointee = true
                
                continuation.resume(with: .success(value))
            }
        }
    }
    
    private func decodeResponse<T: Codable>(_ response: Any) -> AnyPublisher<T, Error> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let object: T = try self.decodeResponse(response)
                    
                    DispatchQueue.main.async {
                        promise(.success(object))
                    }
                    
                } catch let error {
                    promise(.failure(error))
                }
            }

        }
        .eraseToAnyPublisher()
    }
    
    private func decodeResponse<T: Codable>(_ response: Any) throws -> T {
        if let dict = response as? Dictionary<String, Any>,
           dict.keys.contains("deleted") {
            throw APIManagerError.deleted
        }
        
        if response is NSNull {
            throw APIManagerError.noData
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: response)
        let object = try JSONDecoder().decode(T.self, from: jsonData)
        
        return object
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

private struct TimeoutError: LocalizedError {
  var errorDescription: String? = "Task timed out before completion"
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
