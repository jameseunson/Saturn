//
//  SearchView.swift
//  Saturn
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import SwiftUI
import Factory

struct SearchView: View {
    @Injected(\.settingsManager) private var settingsManager
    @Environment(\.isSearching) private var isSearching: Bool
    
    @ObservedObject var interactor = SearchInteractor()
    
    @State var searchQuery: String = ""
    @State var displayingSafariURL: URL?
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingConfirmSheetForStory: StoryRowViewModel?
    
    @State var displayingFilter: Bool = false
    @State var selectedFilter: SearchDateFilter = .anyTime
    
    var body: some View {
        VStack {
            SearchFilterView(displayingFilter: $displayingFilter,
                             selectedFilter: $selectedFilter)
            
            switch interactor.results {
            case let .loaded(response: results):
                if results.isEmpty {
                    Text("No results for '\(searchQuery)'")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    ScrollView {
                        SearchResultsView(results: results,
                                          searchQuery: $searchQuery,
                                          displayingSafariURL: $displayingSafariURL,
                                          selectedUser: $selectedUser,
                                          displayingConfirmSheetForStory: $displayingConfirmSheetForStory)
                    }
                }
            case .loading:
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .failed:
                EmptyView()
                
            case .notLoading:
                if settingsManager.searchHistory().history.count > 0 {
                    SearchHistoryView() { item in
                        interactor.deleteSearchHistoryItem(item: item)
                        
                    } onClearSearchHistory: {
                        interactor.clearSearchHistory()
                        
                    } onSelectSearchHistoryItem: { item in
                        searchQuery = item.query
                        interactor.submit(item.query, with: selectedFilter)
                    }
                } else {
                    Spacer()
                }
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search stories or users")
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .submitLabel(.search)
        .onSubmit(of: .search, {
            interactor.submit(searchQuery, with: selectedFilter)
        })
        .onAppear {
            if selectedFilter != settingsManager.searchDateFilter() {
                selectedFilter = settingsManager.searchDateFilter()
            }
            interactor.activate()
        }
        .onChange(of: searchQuery) { value in
            if searchQuery.isEmpty && !isSearching {
                interactor.clearActiveSearch()
            }
        }
        .onChange(of: selectedFilter, perform: { newFilter in
            if searchQuery.isEmpty { return }
            interactor.submit(searchQuery, with: newFilter)
        })
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .modifier(StoryContextSheetModifier(displayingConfirmSheetForStory: $displayingConfirmSheetForStory,
                                            selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            onTapVote: nil))
        .sheet(isPresented: createBoolBinding(from: $selectedShareItem), content: {
            if let url = selectedShareItem {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
        .navigationDestination(isPresented: createBoolBinding(from: $selectedUser)) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .confirmationDialog("Select date filter", isPresented: $displayingFilter) {
            ForEach(SearchDateFilter.allCases) { f in
                Button(f == selectedFilter ? f.rawValue + "   ✓" : f.rawValue) {
                    selectedFilter = f
                    settingsManager.set(value: .searchDateFilter(f), for: .searchDateFilter)
                }
            }
        } message: {
            Text("Select date filter")
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(interactor: SearchInteractor(results: .notLoading))
        SearchView(interactor: SearchInteractor(results: .loaded(response: [])))
        SearchView(interactor: SearchInteractor(results: .loaded(response: [SearchResultItem.searchResult(SearchItem.createFakeSearchItem()), SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.user(User.createFakeUser())])))
    }
}

enum SearchDateFilter: String, CaseIterable, Identifiable, Codable {
    var id: Self {
        return self
    }
    
    case anyTime = "Any time"
    case past24h = "Past 24h"
    case pastWeek = "Past Week"
    case pastMonth = "Past Month"
    case pastYear = "Past Year"
    
    func startDate() -> Date? {
        let calendar = Calendar.current
        switch self {
        case .anyTime:
            return nil
        case .past24h:
            return calendar.date(byAdding: .day, value: -1, to: Date())
        case .pastWeek:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: Date())
        case .pastMonth:
            return calendar.date(byAdding: .month, value: -1, to: Date())
        case .pastYear:
            return calendar.date(byAdding: .year, value: -1, to: Date())
        }
    }
}
