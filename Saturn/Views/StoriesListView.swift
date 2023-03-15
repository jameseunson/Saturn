//
//  StoriesListView.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI
import AlertToast

struct StoriesListView: View {
    @StateObject var interactor: StoriesListInteractor
    
    @State var isSettingsVisible: Bool = false
    @State var isSearchVisible: Bool = false
    @State var selectedShareItem: URL?
    @State var selectedUser: String?
    @State var displayingSafariURL: URL?
    
    @State var cacheLoadState: CacheLoadState = .refreshNotAvailable
    @State var canLoadNextPage: Bool = true
    @State var showConnectionAlert: Bool = false
    
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
            case .loaded, .loadingMore, .failed:
                ZStack(alignment: .top) {
                    contentScrollView()
                    
                    if cacheLoadState == .refreshNotAvailable {
                        EmptyView()
                    } else {
                        StoriesListRefreshView(cacheLoadState: $cacheLoadState) {
                            interactor.didTapRefreshButton()
                        }
                    }
                }
                .navigationDestination(for: Story.self) { story in
                    let interactor = StoryDetailInteractor(story: story)
                    StoryDetailView(interactor: interactor)
                        .navigationTitle(story.title)
                }
                .refreshable {
                    await interactor.refreshStories()
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
        .onAppear {
            interactor.activate()
        }
        .onReceive(NetworkConnectivityManager.instance.isConnectedPublisher) { output in
            showConnectionAlert = !output
        }
        .onReceive(interactor.$cacheLoadState) { output in
            cacheLoadState = output
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
                        StoryRowView(story: StoryRowViewModel(story: story),
                                     onTapArticleLink: { url in self.displayingSafariURL = url },
                                     onTapUser: { user in self.selectedUser = user },
                                     showsTextPreview: true)
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
                                Button(action: { selectedShareItem = story.url }, label:
                                {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                })
                                Button(action: { selectedUser = story.by }, label:
                                {
                                    Label(story.by, systemImage: "person.circle")
                                })
                            }
                            .padding([.leading, .trailing], 15)
                            .padding(.bottom, 25)
                    }
                }
                if canLoadNextPage {
                    ListLoadingView()
                }
            }
        }
        .toast(isPresenting: $showConnectionAlert, duration: 5.0, tapToDismiss: true, offsetY: (UIScreen.main.bounds.size.height / 2) - 120, alert: {
            AlertToast(type: .regular, title: "No internet connection")
            
        }, onTap: nil, completion: nil)
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesListView(interactor: StoriesListInteractor(type: .top, stories: [Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!]))
    }
}
