//
//  SettingsInteractor.swift
//  Saturn
//
//  Created by James Eunson on 16/1/2023.
//

import Combine
import Foundation

final class SettingsInteractor: Interactor {
    @Published var settingsValues: [SettingKey: SettingValue] = [:]
    
    override func didBecomeActive() {
        SettingsManager.default.settings.sink { map in
            self.settingsValues = map
        }
        .store(in: &disposeBag)
    }
    
    func set(_ key: SettingKey, value: SettingValue) {
        SettingsManager.default.set(value: value, for: key)
    }
}
