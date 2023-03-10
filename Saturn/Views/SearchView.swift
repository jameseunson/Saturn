//
//  SearchView.swift
//  Saturn
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import SwiftUI

struct SearchView: View {
    @ObservedObject var interactor = SearchInteractor()
    
    @State var searchQuery: String = ""
    @State var displayingSafariURL: URL?
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            GeometryReader { reader in
                ScrollView {
                    VStack(alignment: .leading) {
                        if case .loading = interactor.results {
                            LoadingView()
                                .frame(width: reader.size.width, height: reader.size.height)
                            
                        } else if case let .loaded(results) = interactor.results {
                            SearchResultsView(results: results,
                                              searchQuery: $searchQuery,
                                              displayingSafariURL: $displayingSafariURL)
                            
                        } else if case .notLoading = interactor.results {
                            EmptyView()
                        }
                    }
                }
            }
            
            if case .notLoading = interactor.results,
               Settings.default.searchHistory().history.count > 0 {
                SearchHistoryView(searchQuery: $searchQuery) { item in
                    interactor.deleteSearchHistoryItem(item: item)
                    
                } onClearSearchHistory: {
                    interactor.clearSearchHistory()
                }
            }
        }
        .navigationDestination(for: SearchResultItem.self) { item in
            switch item {
            case let .searchResult(searchItem):
                let story = StoryRowViewModel(searchItem: searchItem)
                StoryDetailView(interactor: StoryDetailInteractor(itemId: story.id))
                    .navigationTitle(story.title)
                
            case let .user(selectedUser):
                UserView(interactor: UserInteractor(user: selectedUser))
                    .navigationTitle(selectedUser.id)
            }
        }
        .searchable(text: $searchQuery)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .onAppear {
            interactor.activate()
        }
        .onChange(of: searchQuery) { newValue in
            interactor.searchQueryChanged(newValue)
        }
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(interactor: SearchInteractor(results: .loaded(response: [])))
        SearchView(interactor: SearchInteractor(results: .loaded(response: [SearchResultItem.searchResult(SearchItem.createFakeSearchItem()), SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.user(User.createFakeUser())])))
    }
}
