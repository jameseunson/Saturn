//
//  APIManager+Defaults.swift
//  Saturn
//
//  Created by James Eunson on 12/4/2023.
//

import Foundation
import Combine

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
    func loadUser(id: String, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<User>, Error> {
        loadUser(id: id, cacheBehavior: cacheBehavior)
    }
    func loadUser(id: String, cacheBehavior: CacheBehavior = .default) async throws -> APIResponse<User> {
        try await loadUser(id: id, cacheBehavior: cacheBehavior)
    }
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<UserItem, Error> {
        loadUserItem(id: id, cacheBehavior: cacheBehavior)
    }
    func loadUserItem(id: Int, cacheBehavior: CacheBehavior = .default) async throws -> UserItem {
        try await loadUserItem(id: id, cacheBehavior: cacheBehavior)
    }
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior = .default) -> AnyPublisher<[UserItem], Error> {
        loadUserItems(ids: ids, cacheBehavior: cacheBehavior)
    }
    func loadUserItems(ids: [Int], cacheBehavior: CacheBehavior = .default) async throws -> [UserItem] {
        try await loadUserItems(ids: ids, cacheBehavior: cacheBehavior)
    }
}
