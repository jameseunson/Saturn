//
//  SearchView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import SwiftUI

struct SearchView: View {
    @ObservedObject var interactor = SearchInteractor()
    
    @State var searchQuery: String = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            GeometryReader { reader in
                List {
                    if case .loading = interactor.results {
                        LoadingView()
                            .frame(width: reader.size.width, height: reader.size.height)
                        
                    } else if case let .loaded(results) = interactor.results {
                        if results.count > 0,
                           results.containsUser() {
                            Section(header: Text("Users")) {
                                ForEach(results) { result in
                                    if case let .user(user) = result {
                                        NavigationLink(value: result) {
                                            HStack {
                                                Image(systemName: "person.circle")
                                                Text(user.id)
                                            }
                                        }
                                    }
                                }
                            }
                            Section(header: Text("Stories")) {
                                ForEach(results) { result in
                                    if case let .searchResult(searchItem) = result {
                                        NavigationLink(value: result) {
                                            StoryRowView(story: StoryRowViewModel(searchItem: searchItem))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: SearchResultItem.self) { item in
            switch item {
            case let .searchResult(searchItem):
                let story = StoryRowViewModel(searchItem: searchItem)
                let interactor = StoryDetailInteractor(storyId: story.id)
                StoryDetailView(interactor: interactor)
                    .navigationTitle(story.title)
                
            case let .user(selectedUser):
                UserView(interactor: UserInteractor(user: selectedUser))
                    .navigationTitle(selectedUser.id)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchQuery)
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .onAppear {
            interactor.activate()
        }
        .onChange(of: searchQuery) { newValue in
            interactor.searchQueryChanged(newValue)
        }
    }
}