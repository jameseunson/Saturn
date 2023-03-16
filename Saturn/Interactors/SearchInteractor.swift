//
//  SearchInteractor.swift
//  Saturn
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
                    .map { (query, $0) }
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.results = .failed
                }
                
            } receiveValue: { query, response in
                self.resultsAccumulator.append(contentsOf: response)
                self.results = .loaded(response: self.resultsAccumulator)
                
                self.updateSearchHistory(with: query)
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
    
    func deleteSearchHistoryItem(item: SettingSearchHistoryItem) {
        let searchHistory = SettingsManager.default.searchHistory()
        var searchHistoryList = searchHistory.history
        
        guard let index = searchHistoryList.firstIndex(of: item) else {
            return
        }
        searchHistoryList.remove(at: index)
        
        SettingsManager.default.set(value: .searchHistory(SettingSearchHistory(history: searchHistoryList)),
                             for: .searchHistory)
    }
    
    func clearSearchHistory() {
        SettingsManager.default.set(value: .searchHistory(SettingSearchHistory()),
                             for: .searchHistory)
    }
    
    // MARK: -
    private func updateSearchHistory(with query: String) {
        let searchHistory = SettingsManager.default.searchHistory()
        var searchHistoryList = searchHistory.history
        
        /// Do not add duplicate search queries
        if searchHistoryList.filter ({ $0.query.lowercased() == query.lowercased() }).count > 0 {
            return
        }

        searchHistoryList.insert(SettingSearchHistoryItem(query: query, timestamp: Date()), at: 0)
        
        /// Ensure list remains at 5 or fewer items
        if searchHistoryList.count > 5 {
            searchHistoryList.removeLast()
        }
        
        SettingsManager.default.set(value: .searchHistory(SettingSearchHistory(history: searchHistoryList)),
                             for: .searchHistory)
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
