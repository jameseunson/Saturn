//
//  StoriesListView.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI

struct StoriesListView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject var interactor: StoriesListInteractor
    
    @State var isSettingsVisible: Bool = false
    @State var isSearchVisible: Bool = false
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingSafariURL: URL?
    @State var displayingConfirmSheetForStory: StoryRowViewModel?
    
    @State var canLoadNextPage: Bool = true
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    init(interactor: StoriesListInteractor) {
        _interactor = .init(wrappedValue: interactor)
        #if DEBUG
        if interactor.stories.count > 0 {
            displayingSwiftUIPreview = true
        }
        #endif
    }
    
    var body: some View {
        ZStack {
            switch interactor.loadingState {
            case .loaded, .loadingMore, .failed, .refreshing:
                ZStack(alignment: .top) {
                    contentScrollView()
                    
                    if case .refreshing(let source) = interactor.loadingState,
                       source == .autoRefresh {
                        StoriesListRefreshView()
                    }
                }
                .navigationDestination(for: StoryRowViewModel.self) { viewModel in
                    let interactor = StoryDetailInteractor(story: viewModel)
                    StoryDetailView(interactor: interactor)
                        .navigationTitle(viewModel.title)
                }
                .refreshable {
                    Task {
                        await interactor.refreshStories(source: .pullToRefresh)
                    }
                }
                
                if isSearchVisible {
                    SearchNavigationView(isSearchVisible: $isSearchVisible)
                }
                
            case .initialLoad:
                LoadingView(isFailed: .constant(false))
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
        .navigationDestination(isPresented: createBoolBinding(from: $selectedUser)) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $isSettingsVisible, content: {
            SettingsNavigationView(isSettingsVisible: $isSettingsVisible)
        })
        .sheet(isPresented: createBoolBinding(from: $selectedShareItem), content: {
            if let url = selectedShareItem {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
            }
        })
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .modifier(StoryContextSheetModifier(displayingConfirmSheetForStory: $displayingConfirmSheetForStory,
                                            selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            onTapVote: { direction in
            if let story = displayingConfirmSheetForStory {
                self.interactor.didTapVote(item: story, direction: direction)
            }
        }))
        .onAppear {
            interactor.activate()
            if case .loaded = interactor.loadingState {
                interactor.evaluateRefreshContent()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active,
               case .loaded = interactor.loadingState {
                interactor.evaluateRefreshContent()
            }
        }
        .onReceive(interactor.$loadingState) { output in
            print("loadingState: \(output)")
        }
        .onReceive(interactor.$canLoadNextPage) { output in
            canLoadNextPage = output
        }
    }
    
    func contentScrollView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(interactor.stories) { story in
                    Divider()
                        .padding(.bottom, 10)
                        .padding(.leading, 15)
                    NavigationLink(value: story) {
                        StoryRowView(story: story,
                                     onTapArticleLink: { url in self.displayingSafariURL = url },
                                     onTapUser: { user in self.selectedUser = user },
                                     onTapVote: { direction in self.interactor.didTapVote(item: story, direction: direction) },
                                     onTapSheet: { story in self.displayingConfirmSheetForStory = story },
                                     context: .storiesList)
                        .onAppear {
                            #if DEBUG
                            if displayingSwiftUIPreview {
                                return
                            }
                            #endif
                            if story == interactor.stories.last,
                               canLoadNextPage {
                                interactor.loadNextPageFromSource()
                            }
                        }
                        .contextMenu {
                            if SaturnKeychainWrapper.shared.isLoggedIn,
                               let vote = story.vote {
                                if vote.directions.contains(.upvote) {
                                    Button(action: {
                                        interactor.didTapVote(item: story, direction: .upvote)
                                    }, label: {
                                        Label("Upvote", systemImage: "arrow.up")
                                    })
                                }
                                if vote.directions.contains(.downvote) {
                                    Button(action: {
                                        interactor.didTapVote(item: story, direction: .downvote)
                                    }, label: {
                                        Label("Downvote", systemImage: "arrow.down")
                                    })
                                }
                            }
                            Button(action: { selectedShareItem = .story(story) }, label:
                            {
                                Label("Share", systemImage: "square.and.arrow.up")
                            })
                            Button(action: { selectedUser = story.author }, label:
                            {
                                Label(story.author, systemImage: "person.circle")
                            })
                        }
                        .padding(.bottom, SaturnKeychainWrapper.shared.isLoggedIn ? 0 : 25)
                    }
                    .buttonStyle(StoriesListButtonStyle())
                }
                if canLoadNextPage,
                   interactor.loadingState == .loadingMore {
                    ListLoadingView()
                }
            }
        }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesListView(interactor: StoriesListInteractor(type: .top, stories: [StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!)]))
    }
}

struct StoriesListButtonStyle: ButtonStyle {
    public func makeBody(configuration: StoriesListButtonStyle.Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 1 : 1)
    }
}
