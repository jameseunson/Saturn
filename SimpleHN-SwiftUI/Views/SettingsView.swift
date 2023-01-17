//
//  SettingsView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var interactor = SettingsInteractor()
    
    @State var settingsMap: [SettingKey: Bool] = [:]
    
    var body: some View {
        List {
            Section {
                ForEach(SettingKey.allCases, id: \.self) { key in
                    HStack {
                        Toggle(key.rawValue, isOn: bindingForSetting(key))
                    }
                    .onTapGesture {
                        settingsMap[key] = !settingsMap[key, default: false]
                        interactor.set(key, value: settingsMap[key, default: false])
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Author")
                    Spacer()
                    Text("James Eunson")
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Support")
                    Spacer()
                    Text("https://simple.hn")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("Feedback")
                    Spacer()
                    Text("Send")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    if let url = URL(string: "https://simple.hn/feedback") {
                        UIApplication.shared.open(url)
                    }
                }
                
            } header: {
                Text("About")
            } footer: {
                Text("Written in Swift 5, Combine and SwiftUI in late 2022/early 2023")
            }
        }
        .onAppear {
            interactor.activate()
        }
        .onReceive(interactor.$settingsValues) { output in
            settingsMap = output
        }
    }
    
    func bindingForSetting(_ key: SettingKey) -> Binding<Bool> {
        Binding {
            settingsMap[key] ?? false
        } set: { value in
            settingsMap[key] = value
        }
    }
}
