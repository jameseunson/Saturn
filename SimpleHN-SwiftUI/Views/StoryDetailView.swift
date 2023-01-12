//
//  StoryDetailView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 8/1/2023.
//

import Foundation
import SwiftUI

struct StoryDetailView: View {
    let story: Story
    @StateObject var viewModel: StoryDetailViewModel
    @State private var isShowingSafariView = false
    @State private var commentsExpanded: Dictionary<CommentViewModel, CommentExpandedState> = [:]
    
    @State var isShareVisible: Bool = false
    @State var isUserVisible: Bool = false
    
    var body: some View {
        VStack {
            NavigationLink(destination: UserView(), isActive: $isUserVisible) {
                EmptyView()
            }
            .hidden()
            ScrollView {
                VStack {
                    StoryRowView(story: story)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        .onTapGesture {
                            isShowingSafariView = true
                        }
                    Divider()
                }
                .padding(10)
                
                if viewModel.comments.count == 0 {
                    ListLoadingView()
                        .listRowSeparator(.hidden)
                        .padding(10)
                    
                } else {
                    ForEach(viewModel.comments) { comment in
                        CommentView(expanded: binding(for: comment),
                                    comment: comment) { comment in
                            isUserVisible = true
                            
                        } onTapOptions: { comment in
                            print("test")
                            
                        } onToggleExpanded: { comment, expanded in
                            self.viewModel.updateExpanded(commentsExpanded, for: comment, expanded)
                        }
                        .padding(10)
                    }
                }
            }
            .onAppear {
                viewModel.activate()
            }
            .refreshable {
                await viewModel.refreshComments()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShareVisible = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShareVisible, content: {
            if let url = story.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                if #available(iOS 16, *) {
                    sheet.presentationDetents([.medium])
                } else {
                    sheet
                }
            }
        })
        .sheet(isPresented: $isShowingSafariView) {
            if let url = story.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onReceive(viewModel.$commentsExpanded) { output in
            commentsExpanded = output
        }
    }
    
    func binding(for comment: CommentViewModel) -> Binding<CommentExpandedState> {
        return Binding {
            return self.commentsExpanded[comment] ?? .expanded
        } set: {
            self.commentsExpanded[comment] = $0
        }
    }
}
