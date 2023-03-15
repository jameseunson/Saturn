//
//  SaturnApp.swift
//  Saturn
//
//  Created by James Eunson on 7/1/2023.
//

import SwiftUI
import FirebaseCore
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct AppLauncher {
    static func main() throws {
        if NSClassFromString("XCTestCase") == nil {
            SaturnApp.main()
        } else {
            TestApp.main()
        }
    }
}

struct SaturnApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct TestApp: App {
    var body: some Scene {
        WindowGroup { Text("Running Unit Tests") }
    }
}
