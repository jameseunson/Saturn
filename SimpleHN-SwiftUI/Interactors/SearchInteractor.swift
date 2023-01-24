//
//  SearchInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 18/1/2023.
//

import Foundation
import Combine

final class SearchInteractor: Interactor {
    @Published var results: LoadableResource<[SearchResultItem]> = .notLoading
    
    private let apiManager = SearchAPIManager()
    private let querySubject = PassthroughSubject<String, Never>()
    
    private var resultsAccumulator = [SearchResultItem]()
    
    override func didBecomeActive() {
        querySubject
            .filter { $0.count > 0 }
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { _ in
                self.resultsAccumulator.removeAll()
                self.results = .loading
            })
            .flatMap { query in
                self.apiManager.search(query: query)
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.results = .failed
                }
                
            } receiveValue: { response in
                self.resultsAccumulator.append(contentsOf: response)
                self.results = .loaded(response: self.resultsAccumulator)
            }
            .store(in: &disposeBag)
    }
    
    func searchQueryChanged(_ query: String) {
        querySubject.send(query)
    }
}

extension Array where Element == SearchResultItem {
    func containsUser() -> Bool {
        for item in self {
            if case .user(_) = item {
                return true
            }
        }
        return false
    }
}
