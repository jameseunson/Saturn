//
//  RootView.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Foundation
import SwiftUI
import AlertToast

struct RootView: View {
    @StateObject var interactor = RootInteractor()
    
    @State var titleForUser = "User"
    @State var showConnectionAlert: Bool = false
    
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
                        .navigationTitle(titleForUser)
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
        .onReceive(SaturnKeychainWrapper.shared.$isLoggedIn) { output in
            if output,
               let username = SaturnKeychainWrapper.shared.retrieve(for: .username) {
                titleForUser = username
            } else {
                titleForUser = "User"
            }
        }
        .onReceive(NetworkConnectivityManager.instance.isConnectedPublisher) { output in
            showConnectionAlert = !output
        }
        .toast(isPresenting: $showConnectionAlert, duration: 5.0, tapToDismiss: true, offsetY: (UIScreen.main.bounds.size.height / 2) - 120, alert: {
            AlertToast(type: .regular, title: "No internet connection")
            
        }, onTap: nil, completion: nil)
    }
}
