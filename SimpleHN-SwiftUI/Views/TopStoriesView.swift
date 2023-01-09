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
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .navigationDestination(for: Story.self) { story in
                StoryDetailView(story: story)
                    .environmentObject(StoryDetailViewModel(story: story))
                    .navigationTitle(story.title)
            }
            .refreshable {
                await viewModel.refreshStories()
            }
            .listStyle(.plain)
        }
    }
}

struct TopStoriesView_Previews: PreviewProvider {
    static var previews: some View {
        TopStoriesView()
            .environmentObject(TopStoriesViewModel())
    }
}
