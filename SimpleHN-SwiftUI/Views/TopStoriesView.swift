//
//  TopStoriesView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI

struct TopStoriesView: View {
    @ObservedObject var interactor = TopStoriesInteractor()
    @State var isSettingsVisible: Bool = false
    
    var body: some View {
        if case .initialLoad = interactor.loadingState {
            LoadingView()
            .onAppear {
                interactor.activate()
            }
        } else {
            List {
                ForEach(interactor.stories) { story in
                    NavigationLink(value: story) {
                        StoryRowView(story: StoryRowViewModel(story: story))
                            .onAppear {
                                if story == interactor.stories.last {
                                    interactor.loadNextPage()
                                }
                            }
                    }
                }
                ListLoadingView()
            }
            .navigationDestination(for: Story.self) { story in
                let interactor = StoryDetailInteractor(story: story)
                StoryDetailView(story: story, interactor: interactor)
                    .navigationTitle(story.title)
            }
            .refreshable {
                await interactor.refreshStories()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        isSettingsVisible = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // TODO:
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $isSettingsVisible, content: {
                SettingsNavigationView(isSettingsVisible: $isSettingsVisible)
            })
            .listStyle(.plain)
        }
    }
}

struct SettingsNavigationView: View {
    @Binding var isSettingsVisible: Bool
    
    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            isSettingsVisible = false
                        } label: {
                            Text("Done")
                                .fontWeight(.medium)
                        }

                    }
                }
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
            .environmentObject(TopStoriesInteractor())
    }
}
