//
//  APIManager.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 7/1/2023.
//

import Combine
import Foundation
import FirebaseCore
import Firebase
import FirebaseDatabase

final class APIManager {
    let cache = APIResponseCache()
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
                    return self.loadStory(id: id).map { UserItem.story($0) }.eraseToAnyPublisher()
                    
                } else if type == "comment" {
                    return self.loadComment(id: id).map { UserItem.comment($0) }.eraseToAnyPublisher()
                    
                } else {
                    // TODO: Handle other types
                    return Empty().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func loadUser(id: String) -> AnyPublisher<User, Error> {
        return retrieve(from: "v0/user/\(id)")
            .tryMap { response in
                return try self.decodeResponse(response)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: -
    private func retrieveObject<T: Codable>(id: Int) -> AnyPublisher<T, Error> {
        return retrieve(from: "v0/item/\(id)")
            .tryMap { response -> T? in
                do {
                    return try self.decodeResponse(response)
                    
                } catch APIManagerError.deleted {
                    return nil /// Don't trigger an error if the response is empty, just ignore
                    
                } catch let error {
                    throw error
                }
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
        .timeout(.seconds(5), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func retrieveObject<T: Codable>(id: Int) async throws -> T {
        let response = try await retrieve(from: "v0/item/\(id)")
        return try self.decodeResponse(response)
    }
    
    private func retrieve(from url: String) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
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
                continuation.resume(with: .success(value))
            }
        }
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

