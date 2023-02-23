//
//  StoriesView.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI
import AlertToast

struct StoriesView: View {
    @StateObject var interactor: StoriesInteractor
    
    @State var isSettingsVisible: Bool = false
    @State var isSearchVisible: Bool = false
    @State var selectedShareItem: URL?
    @State var selectedUser: String?
    @State var displayingSafariURL: URL?
    
    @State var isLoading: Bool = false
    @State var favIcons: [Story: Image] = [:]
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    init(interactor: StoriesInteractor) {
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
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(x: 1.2, y: 1.2, anchor: .center)
                                .padding([.leading, .trailing], 30)
                                .padding([.top, .bottom], 15)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundStyle(.ultraThinMaterial)
                        }
                        .offset(.init(width: 0, height: 20))
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
        .toast(isPresenting: isFailedBinding(), duration: 5.0, tapToDismiss: true, offsetY: 250, alert: {
            AlertToast(type: .regular, title: "No internet connection")
            
        }, onTap: nil, completion: nil)
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
                                if story == interactor.stories.last {
                                    interactor.loadNextPage()
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
                ListLoadingView()
            }
        }
    }
    
    // MARK: - Bindings
    func isFailedBinding() -> Binding<Bool> {
        Binding {
            interactor.loadingState == .failed
        } set: { _ in
//            if !value {
//                interactor.loadingState = .initialLoad
//                interactor.loadNextPage()
//            }
        }
    }
}

struct StoriesView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesView(interactor: StoriesInteractor(type: .top, stories: [Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!, Story.fakeStory()!]))
    }
}

extension UIColor {
    var inverted: UIColor {
        var a: CGFloat = 0.0, r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0
        return getRed(&r, green: &g, blue: &b, alpha: &a) ? UIColor(red: 1.0-r, green: 1.0-g, blue: 1.0-b, alpha: a) : .black
    }
}
