//
//  FavIconLoader.swift
//  Saturn
//
//  Created by James Eunson on 19/4/2023.
//

import Foundation
import Combine
import SwiftUI
import Factory

protocol FavIconLoading: AnyObject {
    func loadFaviconsForStories(_ viewModels: [StoryRowViewModel])
    func loadFaviconsForUserItemStories(_ viewModels: [UserItemViewModel])
    func clearFavIcons()
    
    var favIcons: AnyPublisher<[String: Image], Error> { get }
}

final class FavIconLoader: FavIconLoading {
    @Injected(\.apiManager) private var apiManager
    
    lazy var favIcons: AnyPublisher<[String: Image], Error> = favIconsSubject.eraseToAnyPublisher()
    private var favIconsSubject = CurrentValueSubject<[String: Image], Error>([:])
    
    func loadFaviconsForStories(_ viewModels: [StoryRowViewModel]) {
        Task {
            let images = try await withThrowingTaskGroup(of: (Image, StoryRowViewModel)?.self, body: { group in
                for model in viewModels {
                    group.addTask {
                        do {
                            return (try await self.apiManager.getImage(for: model), model)
                        } catch {
                            return nil
                        }
                    }
                }
                var tuples = [(Image, StoryRowViewModel)]()
                for try await item in group {
                    if let item {
                        tuples.append(item)
                    }
                }
                return tuples
            })
            
            var mutableFavIcons = self.favIconsSubject.value
            for (image, model) in images {
                mutableFavIcons[String(model.id)] = image
            }
            self.favIconsSubject.send(mutableFavIcons)
        }
    }
    
    func loadFaviconsForUserItemStories(_ viewModels: [UserItemViewModel]) {
        let stories = viewModels.compactMap { model in
            if case let .story(storyModel) = model {
                return storyModel
            }
            return nil
        }
        loadFaviconsForStories(stories)
    }
    
    func clearFavIcons() {
        favIconsSubject.send([:])
    }
}
