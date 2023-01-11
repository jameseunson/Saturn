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
    
    @State var isShareVisible: Bool = false
    @State var isUserVisible: Bool = false
    
    var body: some View {
        VStack {
            NavigationLink(destination: UserView(), isActive: $isUserVisible) {
                EmptyView()
            }
            .hidden()
            List {
                VStack {
                    StoryRowView(story: story)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        .onTapGesture {
                            isShowingSafariView = true
                        }
                    Divider()
                }
                
                if viewModel.comments.count == 0 {
                    ListLoadingView()
                        .listRowSeparator(.hidden)
                    
                } else {
                    ForEach(viewModel.comments) { comment in
                        CommentView(comment: comment) { comment in
                            isUserVisible = true
                            
                        } onTapOptions: { comment in
                            print("test")
                            
                        } onTapHeader: { comment in
                            print("test")
                        }
                    }
                }
            }
            .listStyle(.plain)
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
    }
}
