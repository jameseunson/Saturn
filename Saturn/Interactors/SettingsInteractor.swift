//
//  SettingsInteractor.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Combine
import Foundation
import Factory

final class SettingsInteractor: Interactor {
    @Published var settingsValues: [SettingKey: SettingValue] = [:]
    @Injected(\.settingsManager) private var settingsManager
    
    override func didBecomeActive() {
        settingsManager.settings.sink { map in
            self.settingsValues = map
        }
        .store(in: &disposeBag)
    }
    
    func set(_ key: SettingKey, value: SettingValue) {
        settingsManager.set(value: value, for: key)
    }
}
