//
//  StoriesListView.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import Factory
import SwiftUI

struct StoriesListView: View {
    @Environment(\.scenePhase) var scenePhase
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.appRemoteConfig) private var appRemoteConfig
    @Injected(\.layoutManager) private var layoutManager
    
    @StateObject var interactor: StoriesListInteractor
    
    @State var isSettingsVisible: Bool = false
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
                        
                    } else if interactor.showPromptToManuallyRefresh {
                        StoriesListRefreshView(type: .prompt(onTapRefreshButton: {
                            interactor.didTapManualRefreshPrompt()
                        }))
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
                
            case .initialLoad:
                LoadingView(isFailed: .constant(false))
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
                interactor.evaluateRefreshContent(triggerEvent: .appear)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active,
               case .loaded = interactor.loadingState {
                interactor.evaluateRefreshContent(triggerEvent: .appear)
            }
        }
        .onReceive(interactor.$loadingState) { output in
            print("loadingState: \(output)")
        }
        .onReceive(interactor.$canLoadNextPage) { output in
            canLoadNextPage = output
        }
        .background(NavBarAccessor { navBar in
            layoutManager.navBarHeight = navBar.bounds.height
         })
    }
    
    func contentScrollView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Divider()
                    .padding(.leading, 15)
                ForEach(interactor.stories) { story in
                    NavigationLink(value: story) {
                        StoryRowView(story: story,
                                     image: bindingForStoryImage(story: story),
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
                            if keychainWrapper.isLoggedIn,
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
    
    func bindingForStoryImage(story: StoryRowViewModel) -> Binding<Image?> {
        Binding { return interactor.favIcons[String(story.id)] } set: { _ in }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoriesListView(interactor: StoriesListInteractor(type: .top,
                                                              stories: [StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!), StoryRowViewModel(story: Story.fakeStory()!)]))
        }
    }
}

struct StoriesListButtonStyle: ButtonStyle {
    public func makeBody(configuration: StoriesListButtonStyle.Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 1 : 1)
            .background(configuration.isPressed ? Color(uiColor: UIColor.systemGray3) : Color.clear)
    }
}
