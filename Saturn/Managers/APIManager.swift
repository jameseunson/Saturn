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

final class APIManager {
    let ref: DatabaseReference! = Database.database(url: "https://hacker-news.firebaseio.com").reference()

    func loadStories(ids: [Int]) -> AnyPublisher<[Story], Error> {
        let stories = ids.map { return self.loadStory(id: $0) }
        return Publishers.MergeMany(stories)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func loadStories(ids: [Int]) async throws -> [Story] {
        return try await withThrowingTaskGroup(of: Story.self, body: { group in
            for id in ids {
                group.addTask {
                    return try await self.loadStory(id: id)
                }
            }
            var stories = [Story]()
            for try await story in group {
                stories.append(story)
            }
            
            return stories
        })
    }
    
    func loadStoryIds(type: StoryListType) -> AnyPublisher<Array<Int>, Error> {
        return retrieve(from: type.path)
            .tryMap { response in
                guard let ids = response as? Array<Int> else {
                    throw APIManagerError.generic
                }
                return ids
            }
            .eraseToAnyPublisher()
    }
    
    func loadStoryIds(type: StoryListType) async throws -> Array<Int> {
        if let response = try await retrieve(from: type.path) as? Array<Int> {
            return response
        } else {
            throw APIManagerError.generic
        }
    }
    
    func loadStory(id: Int) -> AnyPublisher<Story, Error> {
        return retrieveObject(id: id)
    }
    
    func loadStory(id: Int) async throws -> Story {
        return try await retrieveObject(id: id)
    }
    
    func loadComment(id: Int) -> AnyPublisher<Comment, Error> {
        return retrieveObject(id: id)
    }
    
    func loadComment(id: Int) async throws -> Comment {
        return try await retrieveObject(id: id)
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
                if type == "story" {
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
    
    // MARK: -
    private func retrieveObject<T: Codable>(id: Int) -> AnyPublisher<T, Error> {
        if let response = APIMemoryResponseCache.default.get(for: id) {
            return Just(response)
                .handleEvents(receiveOutput: { _ in
                    print("cache hit: \(id)")
                })
                .flatMap { response in
                    self.decodeResponse(response)
                }
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }
        
        return retrieve(from: "v0/item/\(id)")
            .handleEvents(receiveOutput: { response in
                print("cache miss: \(id)")
                APIMemoryResponseCache.default.set(value: response, for: id)
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
    
    private func retrieveObject<T: Codable>(id: Int) async throws -> T {
        let response = try await retrieve(from: "v0/item/\(id)")
        return try self.decodeResponse(response)
    }
    
    private func retrieve(from url: String) async throws -> Any {
        let didTimeout = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        let didComplete = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
                if didComplete.pointee {
                    return
                }
                didTimeout.pointee = true

                continuation.resume(throwing: TimeoutError())
            }
            self.ref.child(url).getData { error, snapshot in
                guard error == nil,
                      let value = snapshot?.value else {
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: APIManagerError.generic)
                    }
                    return
                }
                if didTimeout.pointee {
                    return
                }
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
