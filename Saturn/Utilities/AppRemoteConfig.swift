//
//  AppRemoteConfig.swift
//  Saturn
//
//  Created by James Eunson on 18/1/2023.
//

import Foundation
import Firebase
import FirebaseRemoteConfig

final class AppRemoteConfig {
    static let instance = AppRemoteConfig()
    
    let remoteConfig: RemoteConfig
    
    init() {
        remoteConfig = RemoteConfig.remoteConfig()
        remoteConfig.setDefaults(fromPlist: "remote_config_defaults")
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = (12 * 3600) // 12 hours as recommended by docs
        remoteConfig.configSettings = settings
    }
    
    func isSearchEnabled() -> Bool {
        return remoteConfig.configValue(forKey: RemoteConfigKeys.searchEnabled.rawValue).boolValue
    }
    
    func isLoggedInEnabled() -> Bool {
        return remoteConfig.configValue(forKey: RemoteConfigKeys.loggedInEnabled.rawValue).boolValue
    }
}

enum RemoteConfigKeys: String {
    case searchEnabled
    case loggedInEnabled
}

