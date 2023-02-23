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
                StoriesView(interactor: StoriesInteractor(type: .top))
                    .navigationTitle("Top")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Top", systemImage: "list.dash")
            }
            NavigationStack {
                StoriesView(interactor: StoriesInteractor(type: .new))
                    .navigationTitle("New")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("New", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationStack {
                StoriesView(interactor: StoriesInteractor(type: .show))
                    .navigationTitle("Show")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Show", systemImage: "binoculars")
            }
            NavigationStack {
                StoriesView(interactor: StoriesInteractor(type: .ask))
                    .navigationTitle("Ask")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Ask", systemImage: "text.bubble")
            }
        }
        .onAppear {
            interactor.activate()
        }
    }
}
