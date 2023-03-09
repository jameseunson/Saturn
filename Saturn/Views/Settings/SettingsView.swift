//
//  SettingsView.swift
//  Saturn
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
                ForEach(SettingKey.allCases.filter { $0.isUserConfigurable() }, id: \.self) { key in
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
                            SettingsIndentationSelectColorView(selectedColor: indentationColor(),
                                                               lastUserSelectedColor: lastUserSelectedColor())
                        } label: {
                            HStack {
                                Text(key.rawValue)
                                Spacer()
                                if case let .indentationColor(value) = settingsMap[.indentationColor] {
                                    switch value {
                                    case .hnOrange, .default, .userSelected(color: _):
                                        Circle()
                                            .fill(Color.indentationColor())
                                            .frame(width: 25, height: 25)
                                    default:
                                        SettingsIndentationUnknownColorView()
                                    }
                                } else {
                                    SettingsIndentationUnknownColorView()
                                }
                            }
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
                    Text("Feedback")
                    Spacer()
                    Text("Send")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    if let url = URL(string: "mailto:saturnhnapp@gmail.com") {
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
            interactor.set(key, value: .bool(value))
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
            interactor.set(.indentationColor, value: .indentationColor(value))
        }
    }
    
    func lastUserSelectedColor() -> Binding<Color?> {
        Binding {
            if case let .color(color) = settingsMap[.lastUserSelectedColor] {
                return color
            } else {
                return nil
            }
        } set: { value in
            guard let value else { return }
            interactor.set(.lastUserSelectedColor, value: .color(value))
        }
    }
}
