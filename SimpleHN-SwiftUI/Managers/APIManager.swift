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

final class APIManager {
    let ref: DatabaseReference! = Database.database(url: "https://hacker-news.firebaseio.com").reference()

    func loadTopStories(ids: [Int]) -> AnyPublisher<[Story], Error> {
        let stories = ids.map { return self.loadStory(id: $0) }
        return Publishers.MergeMany(stories)
            .collect()
            .map { stories in
                return stories
            }
            .eraseToAnyPublisher()
    }
    
    func loadTopStoryIds() -> AnyPublisher<Array<Int>, Error> {
        return retrieve(from: "v0/topstories")
            .tryMap { response in
                guard let ids = response as? Array<Int> else {
                    throw APIManagerError.generic
                }
                return ids
            }
            .eraseToAnyPublisher()
    }
    
    func loadStory(id: Int) -> AnyPublisher<Story, Error> {
        return retrieveObject(id: id)
    }
    
    func loadComment(id: Int) -> AnyPublisher<Comment, Error> {
        return retrieveObject(id: id)
    }
    
    // MARK: -
    private func retrieveObject<T: Codable>(id: Int) -> AnyPublisher<T, Error> {
        return retrieve(from: "v0/item/\(id)")
            .tryMap { response in
                let jsonData = try JSONSerialization.data(withJSONObject: response)
                let object = try JSONDecoder().decode(T.self, from: jsonData)
                return object
            }
            .eraseToAnyPublisher()
    }
    
    private func retrieve(from url: String) -> AnyPublisher<Any, Error> {
        return Future { [weak self] promise in
            guard let self else { return }
         
            self.ref.child(url).getData { error, snapshot in
                guard error == nil,
                      let value = snapshot?.value else {
                    if let error {
                        promise(.failure(error))
                    } else {
                        promise(.failure(APIManagerError.generic))
                    }
                    return
                }
                promise(.success(value))
            }
        }
        .timeout(.seconds(5), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

enum APIManagerError: Error {
    case generic
}
