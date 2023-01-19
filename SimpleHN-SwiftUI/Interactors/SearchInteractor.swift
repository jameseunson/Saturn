//
//  SearchInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 18/1/2023.
//

import Foundation
import Combine

final class SearchInteractor: Interactor {
    @Published var results: LoadableResource<[SearchItem]> = .notLoading
    
    private let apiManager = SearchAPIManager()
    private let querySubject = PassthroughSubject<String, Never>()
    
    override func didBecomeActive() {
        querySubject
            .filter { $0.count > 0 }
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .flatMap { query in
                self.apiManager.search(query: query)
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                print(completion)
            } receiveValue: { response in
                guard let hits = response?.hits else {
                    return
                }
                self.results = .loaded(response: hits)
            }
            .store(in: &disposeBag)
    }
    
    func searchQueryChanged(_ query: String) {
        querySubject.send(query)
    }
}
