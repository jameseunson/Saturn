//
//  RootView.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Foundation
import SwiftUI
import AlertToast
import Factory

struct RootView: View {
    @Environment(\.scenePhase) var scenePhase
    
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.appRemoteConfig) private var appRemoteConfig
    @Injected(\.persistenceManager) private var persistenceManager
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    @StateObject var interactor = RootInteractor()
    
    @State var titleForUser = "User"
    @State var currentlyDisplayingError: Error?
    
    var body: some View {
        TabView {
            NavigationStack {
                StoriesCategoriesView()
                    .navigationTitle("Stories")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Stories", systemImage: "list.dash")
            }
            NavigationStack {
                SearchView()
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            if appRemoteConfig.isLoggedInEnabled() {
                NavigationStack {
                    LoggedInView()
                        .navigationTitle(titleForUser)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label("User", systemImage: "person")
                }
            }
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .onAppear {
            interactor.activate()
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(named: "AccentColor")
        }
        .onReceive(keychainWrapper.isLoggedInSubject) { output in
            if output,
               let username = keychainWrapper.retrieve(for: .username) {
                titleForUser = username
            } else {
                titleForUser = "User"
            }
        }
        .onReceive(globalErrorStream.errorStream) { output in
            currentlyDisplayingError = output
        }
        .toast(isPresenting: createBoolBinding(from: $currentlyDisplayingError), duration: 5.0, tapToDismiss: true, offsetY: (UIScreen.main.bounds.size.height / 2) - 120, alert: {
            AlertToast(type: .regular, title: currentlyDisplayingError?.localizedDescription ?? "An unknown error has occurred")
            
        }, onTap: nil, completion: nil)
        .onChange(of: scenePhase) { _ in
            persistenceManager.saveContext()
        }
    }
}
