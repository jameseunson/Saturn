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
    
    init(results: LoadableResource<[SearchResultItem]> = .notLoading) {
        self.results = results
    }
    
    override func didBecomeActive() {
        querySubject
            .filter { $0.count > 0 }
            .debounce(for: .milliseconds(750), scheduler: RunLoop.main)
            .flatMap { query in
                self.apiManager.search(query: query)
                    .catch { error in
                        return Just([])
                    }
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
        switch results {
        case .loading:
            break
        default:
            if query.count > 0 {
                self.results = .loading
            }
            self.resultsAccumulator.removeAll()
        }
        
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
