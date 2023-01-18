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
    @State var results: [StoryRowViewModel] = []
    
    var body: some View {
        List {
            ForEach(results) { result in
                NavigationLink(value: result) {
                    StoryRowView(story: result)
                }
            }
        }
        .navigationDestination(for: StoryRowViewModel.self) { story in
            let interactor = StoryDetailInteractor(storyId: story.id)
            StoryDetailView(interactor: interactor)
                .navigationTitle(story.title)
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
        .onReceive(interactor.$results) { output in
            if case let .loaded(results) = output {
                self.results = results.map { StoryRowViewModel(searchItem: $0) }
            }
        }
    }
}
