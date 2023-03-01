//
//  StoryImageLoader.swift
//  Saturn
//
//  Created by James Eunson on 1/3/2023.
//

import Foundation
import SwiftUI
import Combine

final class StoryImageLoader {
    static let `default` = StoryImageLoader()
    
    private let cache: APIMemoryResponseCaching
    private let queue = DispatchQueue(label: "StoryImageLoader")
    private var disposeBag = Set<AnyCancellable>()
    
    init(cache: APIMemoryResponseCaching = APIMemoryResponseCache.default) {
        self.cache = cache
    }
    
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    func get(for story: StoryRowViewModel) async -> Image {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else { return }
            self.loadImage(for: story)
                .subscribe(on: self.queue)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("error: \(story.id)")
                        continuation.resume(with: .failure(error))
                    }
                }, receiveValue: { image in
                    print("receive: \(story.id)")
                    continuation.resume(with: .success(image))
                })
                .store(in: &disposeBag)
        }
    }
    
    // MARK: -
    private func loadImage(for story: StoryRowViewModel, cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<Image, Never> {
        guard let imageURL = story.imageURL else {
            return Empty().eraseToAnyPublisher()
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
            return Just(Image(uiImage: image)).eraseToAnyPublisher()
        }
        
        return URLSession.DataTaskPublisher(request: URLRequest(url: imageURL), session: .shared)
            .mapError { _ in APIManagerError.generic }
            .tryMap { (data: Data, urlResponse: URLResponse) -> Image in
                guard let image = UIImage(data: data) else {
                    throw APIManagerError.generic
                }
                self.cache.set(value: .data(data), for: cacheKey)
                return Image(uiImage: image)
            }
            .catch { _ in
                return Empty().eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
