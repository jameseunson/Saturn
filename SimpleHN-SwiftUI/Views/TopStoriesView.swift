//
//  TopStoriesView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI

struct TopStoriesView: View {
    @EnvironmentObject var viewModel: TopStoriesViewModel
    
    var body: some View {
        if case .initialLoad = viewModel.loadingState {
            LoadingView()
            .onAppear {
                viewModel.activate()
            }
        } else {
            List {
                ForEach(viewModel.stories) { story in
                    NavigationLink(value: story) {
                        StoryRowView(story: story)
                            .onAppear {
                                if story == viewModel.stories.last {
                                    viewModel.loadNextPage()
                                }
                            }
                    }
                }
                ListLoadingView()
            }
            .navigationDestination(for: Story.self) { story in
                let viewModel = StoryDetailViewModel(story: story)
                StoryDetailView(story: story, viewModel: viewModel)
                    .navigationTitle(story.title)
            }
            .refreshable {
                await viewModel.refreshStories()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // TODO:
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ListLoadingView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
}

struct TopStoriesView_Previews: PreviewProvider {
    static var previews: some View {
        TopStoriesView()
            .environmentObject(TopStoriesViewModel())
    }
}
