//
//  SearchInteractor.swift
//  Saturn
//
//  Created by James Eunson on 18/1/2023.
//

import Foundation
import Combine
import Factory

final class SearchInteractor: Interactor {
    @Injected(\.settingsManager) private var settingsManager
    @Injected(\.searchApiManager) private var apiManager
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    @Published var results: LoadableResource<[SearchResultItem]> = .notLoading
    private let querySubject = PassthroughSubject<(query: String, filter: SearchDateFilter), Never>()
    
    private var resultsAccumulator = [SearchResultItem]()
    
    init(results: LoadableResource<[SearchResultItem]> = .notLoading) {
        self.results = results
    }
    
    func submit(_ query: String, with dateFilter: SearchDateFilter) {
        guard query.count > 0 else {
            return
        }
        switch results {
        case .loading:
            break
            
        default:
            self.results = .loading
            self.resultsAccumulator.removeAll()
        }
        
        self.apiManager.search(query: query, filter: dateFilter)
            .catch { error in
                return Just([])
            }
            .map { (query, $0) }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.globalErrorStream.addError(error)
                    self.results = .failed
                }
                
            } receiveValue: { query, response in
                self.resultsAccumulator.append(contentsOf: response)
                self.results = .loaded(response: self.resultsAccumulator)
                
                self.updateSearchHistory(with: query)
            }
            .store(in: &disposeBag)
    }
    
    func deleteSearchHistoryItem(item: SettingSearchHistoryItem) {
        let searchHistory = settingsManager.searchHistory()
        var searchHistoryList = searchHistory.history
        
        guard let index = searchHistoryList.firstIndex(of: item) else {
            return
        }
        searchHistoryList.remove(at: index)
        
        settingsManager.set(value: .searchHistory(SettingSearchHistory(history: searchHistoryList)),
                             for: .searchHistory)
    }
    
    func clearSearchHistory() {
        settingsManager.set(value: .searchHistory(SettingSearchHistory()),
                             for: .searchHistory)
    }
    
    func clearActiveSearch() {
        results = .notLoading
    }
    
    // MARK: -
    private func updateSearchHistory(with query: String) {
        let searchHistory = settingsManager.searchHistory()
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
        
        settingsManager.set(value: .searchHistory(SettingSearchHistory(history: searchHistoryList)),
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
    func containsStories() -> Bool {
        for item in self {
            if case .searchResult(_) = item {
                return true
            }
        }
        return false
    }
}
