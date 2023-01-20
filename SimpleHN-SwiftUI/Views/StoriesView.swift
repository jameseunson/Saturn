//
//  StoriesView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI

struct StoriesView: View {
    let type: StoryListType
    
    @ObservedObject var interactor: StoriesInteractor
    @State var isSettingsVisible: Bool = false
    @State var isSearchVisible: Bool = false
    
    init(type: StoryListType) {
        self.type = type
        self.interactor = StoriesInteractor(type: type)
    }
    
    var body: some View {
        ZStack {
            if case .initialLoad = interactor.loadingState {
                LoadingView()
                
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
                .listStyle(.plain)
                
                if isSearchVisible {
                    SearchNavigationView(isSearchVisible: $isSearchVisible)
                }
            }
        }
        .toolbar {
            if !isSearchVisible {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        isSettingsVisible = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                if AppRemoteConfig.instance.isSearchEnabled() {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            isSearchVisible = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isSettingsVisible, content: {
            SettingsNavigationView(isSettingsVisible: $isSettingsVisible)
        })
        .onAppear {
            interactor.activate()
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

struct SearchNavigationView: View {
    @Binding var isSearchVisible: Bool
    
    var body: some View {
        NavigationStack {
            SearchView()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            isSearchVisible = false
                        } label: {
                            Image(systemName: "chevron.left")
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

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesView(type: .top)
            .environmentObject(StoriesInteractor(type: .top))
    }
}
