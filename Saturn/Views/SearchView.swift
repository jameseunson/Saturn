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
    @ObservedObject var interactor = SearchInteractor()
    
    @State var searchQuery: String = ""
    @State var displayingSafariURL: URL?
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingConfirmSheetForStory: StoryRowViewModel?
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            GeometryReader { reader in
                ScrollView {
                    if case .loading = interactor.results {
                        LoadingView()
                            .frame(width: reader.size.width, height: reader.size.height)
                        
                    } else if case let .loaded(results) = interactor.results {
                        if results.isEmpty {
                            Text("No results for '\(searchQuery)'")
                                .foregroundColor(.gray)
                                .frame(width: reader.size.width, height: reader.size.height)
                        } else {
                            SearchResultsView(results: results,
                                              searchQuery: $searchQuery,
                                              displayingSafariURL: $displayingSafariURL,
                                              selectedUser: $selectedUser,
                                              displayingConfirmSheetForStory: $displayingConfirmSheetForStory)
                        }
                        
                    } else if case .notLoading = interactor.results {
                        EmptyView()
                    }
                }
            }
            
            if case .notLoading = interactor.results,
               settingsManager.searchHistory().history.count > 0 {
                SearchHistoryView() { item in
                    interactor.deleteSearchHistoryItem(item: item)
                    
                } onClearSearchHistory: {
                    interactor.clearSearchHistory()
                    
                } onSelectSearchHistoryItem: { item in
                    searchQuery = item.query
                    interactor.submit(item.query)
                }
            }
        }
        .searchable(text: $searchQuery)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .submitLabel(.search)
        .onSubmit(of: .search, {
            interactor.submit(searchQuery)
        })
        .onAppear {
            interactor.activate()
        }
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
