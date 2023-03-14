//
//  RootView.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Foundation
import SwiftUI

struct RootView: View {
    @StateObject var interactor = RootInteractor()
    
    var body: some View {
        TabView {
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .top))
                    .navigationTitle("Top")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Top", systemImage: "list.dash")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .new))
                    .navigationTitle("New")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("New", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .show))
                    .navigationTitle("Show")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Show", systemImage: "binoculars")
            }
            NavigationStack {
                StoriesListView(interactor: StoriesListInteractor(type: .ask))
                    .navigationTitle("Ask")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Ask", systemImage: "text.bubble")
            }
            if AppRemoteConfig.instance.isLoggedInEnabled() {
                NavigationStack {
                    LoggedInView()
                        .navigationTitle("User")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label("User", systemImage: "person")
                }
            }
        }
        .onAppear {
            interactor.activate()
        }
    }
}
