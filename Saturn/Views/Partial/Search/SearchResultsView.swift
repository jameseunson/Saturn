//
//  SearchResultsView.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation
import SwiftUI
import Factory

struct SearchResultsView: View {
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    let results: Array<SearchResultItem>
    @Binding var searchQuery: String
    @Binding var displayingSafariURL: URL?
    
    var body: some View {
        VStack(alignment: .leading) {
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
                            NavigationLink {
                                UserView(interactor: UserInteractor(user: user))
                                    .navigationTitle(user.id)
                            } label: {
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
                if results.containsStories() {
                    Text("Stories")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding([.leading])
                    Divider()
                        .padding([.leading])
                    ForEach(results) { result in
                        if case let .searchResult(searchItem) = result {
                            NavigationLink {
                                let story = StoryRowViewModel(story: Story(searchItem: searchItem))
                                StoryDetailView(interactor: StoryDetailInteractor(itemId: story.id))
                                    .navigationTitle(story.title)
                                
                            } label: {
                                StoryRowView(story: StoryRowViewModel(story: Story(searchItem: searchItem)),
                                             image: .constant(nil), // TODO:
                                             onTapArticleLink: { url in
                                    self.displayingSafariURL = url
                                })
                                .padding(.bottom, keychainWrapper.isLoggedIn ? 0 : 25)
                            }
                            Divider()
                        }
                    }
                }
            } else {
                Text("No results for '\(searchQuery)'")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
