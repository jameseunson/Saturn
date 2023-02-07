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
    
    @State var settingsMap: [SettingKey: SettingValue] = [:]
    
    var body: some View {
        List {
            Section {
                ForEach(SettingKey.allCases, id: \.self) { key in
                    switch Settings.types[key] {
                    case .bool:
                        HStack {
                            Toggle(key.rawValue, isOn: boolForSetting(key))
                        }
                        .onTapGesture {
                            let bool = settingsMap[key, default: .bool(false)]
                            if case let .bool(value) = bool {
                                settingsMap[key] = .bool(!value)
                                interactor.set(key, value: .bool(!value))
                            }
                        }
                    case .enum:
                        NavigationLink {
                            SettingsIndentationSelectColorView(selectedColor: indentationColor())
                        } label: {
                            Text(key.rawValue)
                        }
                    case .none:
                        EmptyView()
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
        .navigationDestination(for: SettingValue.self, destination: { value in
            Text("Hello world")
        })
        .onAppear {
            interactor.activate()
        }
        .onReceive(interactor.$settingsValues) { output in
            settingsMap = output
        }
        .onChange(of: indentationColor().wrappedValue) { newValue in
            settingsMap[.indentationColor] = .indentationColor(newValue)
            interactor.set(.indentationColor, value: .indentationColor(newValue))
        }
    }
    
    func boolForSetting(_ key: SettingKey) -> Binding<Bool> {
        Binding {
            switch settingsMap[key] {
            case let .bool(value):
                return value
            default:
                return false
            }
        } set: { value in
            settingsMap[key] = .bool(value)
        }
    }
    
    func indentationColor() -> Binding<SettingIndentationColor> {
        Binding {
            switch settingsMap[.indentationColor] {
            case let .indentationColor(value):
                return value
            default:
                return .`default`
            }
        } set: { value in
            settingsMap[.indentationColor] = .indentationColor(value)
        }
    }
}
