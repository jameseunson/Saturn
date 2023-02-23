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

    func loadStories(ids: [Int], cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<[Story], Error> {
        let stories = ids.map { return self.loadStory(id: $0, cacheBehavior: cacheBehavior) }
        return Publishers.MergeMany(stories)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func loadStories(ids: [Int], cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> [Story] {
        return try await withThrowingTaskGroup(of: Story.self, body: { group in
            for id in ids {
                group.addTask {
                    return try await self.loadStory(id: id, cacheBehavior: cacheBehavior)
                }
            }
            var stories = [Story]()
            for try await story in group {
                stories.append(story)
            }
            
            return stories
        })
    }
    
    func loadStoryIds(type: StoryListType, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<Array<Int>, Error> {
        if cacheBehavior == .offlineOnly,
           cache.get(for: type.cacheKey) == nil {
            return Empty()
                .eraseToAnyPublisher()
        }
        
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior) {
            return Just(response)
                .tryMap { response in
                    guard let ids = response.value as? Array<Int> else {
                        throw APIManagerError.generic
                    }
                    return ids
                }
                .eraseToAnyPublisher()
            
        } else {
            return retrieve(from: type.path)
                .tryMap { response in
                    guard let ids = response as? Array<Int> else {
                        throw APIManagerError.generic
                    }
                    return ids
                }
                .handleEvents(receiveOutput: { ids in
                    APIMemoryResponseCache.default.set(value: ids, for: type.cacheKey)
                })
                .eraseToAnyPublisher()
        }
    }
    
    func loadStoryIds(type: StoryListType, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> Array<Int> {
        if let response = cache.get(for: type.cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
            let responseArray = response.value as? Array<Int> {
            return responseArray
            
        } else if let response = try await retrieve(from: type.path) as? Array<Int> {
            return response
        } else {
            throw APIManagerError.generic
        }
    }
    
    func loadStory(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<Story, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadStory(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> Story {
        return try await retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<Comment, Error> {
        return retrieveObject(id: id, cacheBehavior: cacheBehavior)
    }
    
    func loadComment(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> Comment {
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
                        .map { UserItem.story($0) }
                        .eraseToAnyPublisher()
                    
                } else if type == "comment" {
                    return self.loadComment(id: id)
                        .flatMap { comment in
                            comment.loadMarkdown()
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
            return UserItem.story(story)
            
        } else if type == "comment" {
            let comment = try await self.loadComment(id: id)
            await comment.loadMarkdown()
            
            return UserItem.comment(comment)

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
    
    
    func loadImage(for story: Story, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<Image, Never> {
        guard let imageURL = StoryRowViewModel(story: story).imageURL else {
            return Empty().eraseToAnyPublisher()
        }
  
        let cacheKey = imageURL.absoluteString
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        
        if let response = cache.get(for: cacheKey),
           response.isValid(cacheBehavior: cacheBehavior),
           let data = response.value as? Data,
           let image = UIImage(data: data) {
            return Just(Image(uiImage: image)).eraseToAnyPublisher()
        }
        
        return URLSession.DataTaskPublisher(request: URLRequest(url: imageURL), session: .shared)
            .mapError { _ in APIManagerError.generic }
            .tryMap { (data: Data, urlResponse: URLResponse) -> Image in
                guard let image = UIImage(data: data) else {
                    throw APIManagerError.generic
                }
                self.cache.set(value: data, for: cacheKey)
                return Image(uiImage: image)
            }
            .catch { _ in
                return Empty().eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: -
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<T, Error> {
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehavior) {
            return Just(response)
                .handleEvents(receiveOutput: { _ in
                    if self.isDebugLoggingEnabled { print("cache hit: \(id)") }
                })
                .flatMap { response in
                    return self.decodeResponse(response.value)
                }
                .compactMap { $0 }
                .eraseToAnyPublisher()
        } else {
            if isDebugLoggingEnabled { print("cache miss: \(id)") }
            return self.retrieveObjectFromNetwork(id: id)
        }
    }
    
    private func retrieveObjectFromNetwork<T: Codable>(id: Int) -> AnyPublisher<T, Error> {
        return retrieve(from: "v0/item/\(id)")
            .handleEvents(receiveOutput: { response in
                self.cache.set(value: response, for: String(id))
            })
            .flatMap { response in
                self.decodeResponse(response)
            }
            .compactMap { $0 }
            .eraseToAnyPublisher()
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
    
    private func retrieveObject<T: Codable>(id: Int, cacheBehavior: APIMemoryResponseCacheBehavior = .default) async throws -> T {
        if let response = cache.get(for: String(id)),
           response.isValid(cacheBehavior: cacheBehavior) {
            if isDebugLoggingEnabled { print("cache hit (async): \(id)") }
            return try self.decodeResponse(response.value)
            
        } else {
            if isDebugLoggingEnabled { print("cache miss (async): \(id)") }
            let response = try await retrieve(from: "v0/item/\(id)")
            self.cache.set(value: response, for: String(id))
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
                           NetworkConnectivityManager.instance.isConnected {
                            NetworkConnectivityManager.instance.isConnected = false
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

private struct TimeoutError: LocalizedError {
  var errorDescription: String? = "Task timed out before completion"
}

protocol DatabaseReferencing: AnyObject {
    func childPath(_ pathString: String) -> DatabaseReferencing
    func getChildData(completion block: @escaping (Error?, DataShapshotting?) -> Void)
}

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
