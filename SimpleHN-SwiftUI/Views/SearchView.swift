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
                ScrollView {
                    VStack(alignment: .leading) {
                        if case .loading = interactor.results {
                            LoadingView()
                                .frame(width: reader.size.width, height: reader.size.height)
                            
                        } else if case let .loaded(results) = interactor.results {
                            if results.count > 0 {
                                if results.containsUser() {
                                    Text("Users")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .padding([.leading])
                                    Divider()
                                        .padding([.leading])
                                    ForEach(results) { result in
                                        if case let .user(user) = result {
                                            NavigationLink(value: result) {
                                                HStack {
                                                    Image(systemName: "person.circle")
                                                        .foregroundColor(Color.primary)
                                                    Text(user.id)
                                                        .foregroundColor(Color.primary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                                .padding([.leading, .trailing, .bottom])
                                            }
                                        }
                                    }
                                }
                                Text("Stories")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .padding([.leading])
                                Divider()
                                    .padding([.leading])
                                ForEach(results) { result in
                                    if case let .searchResult(searchItem) = result {
                                        NavigationLink(value: result) {
                                            StoryRowView(story: StoryRowViewModel(searchItem: searchItem),
                                                         onTapArticleLink: { _ in // TODO:
                                            })
                                            .padding([.leading, .trailing])
                                        }
                                        Divider()
                                    }
                                }
                            } else {
                                Text("No results for '\(searchQuery)'")
                                    .foregroundColor(.gray)
                                    .frame(width: reader.size.width, height: reader.size.height)
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
                StoryDetailView(interactor: StoryDetailInteractor(itemId: story.id))
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

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(interactor: SearchInteractor(results: .loaded(response: [])))
        SearchView(interactor: SearchInteractor(results: .loaded(response: [SearchResultItem.searchResult(SearchItem.createFakeSearchItem()), SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.searchResult(SearchItem.createFakeSearchItem()),
            SearchResultItem.user(User.createFakeUser())])))
    }
}
