//
//  SearchResultsView.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation
import SwiftUI

struct SearchResultsView: View {
    let results: Array<SearchResultItem>
    @Binding var searchQuery: String
    @Binding var displayingSafariURL: URL?
    
    var body: some View {
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
                        StoryRowView(story: StoryRowViewModel(story: Story(searchItem: searchItem)),
                                     onTapArticleLink: { url in
                            self.displayingSafariURL = url
                        })
                        .padding(.bottom, 15)
                    }
                    Divider()
                }
            }
        } else {
            Text("No results for '\(searchQuery)'")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
