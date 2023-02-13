//
//  SettingsIndentationColorSelectView.swift
//  Saturn
//
//  Created by James Eunson on 7/2/2023.
//

import Foundation
import SwiftUI

struct SettingsIndentationSelectColorView: View {
    @Binding var selectedColor: SettingIndentationColor
    
    var body: some View {
        List {
            Section {
                ForEach(SettingIndentationColor.allCases, id: \.self) { key in
                    HStack {
                        switch key {
                        case .`default`:
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 25, height: 25)
                            
                        case .hnOrange:
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 25, height: 25)
                            
                        case .userSelected(_):
                            if let color = optionalBindingForUserSelectedColor().wrappedValue {
                                Circle()
                                    .fill(color)
                                    .frame(width: 25, height: 25)
                            } else {
                                SettingsIndentationUnknownColorView()
                            }
                            
                        case .random, .randomPost:
                            SettingsIndentationUnknownColorView()
                        }
                        
                        Text(key.toString())
                        Spacer()
                        
                        switch key {
                        case .`default`, .hnOrange, .random, .randomPost:
                            if selectedColor == key { Image(systemName: "checkmark") }
                        case .userSelected(color: _):
                            if case .userSelected(_) = selectedColor {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedColor = key
                    }
                }
            }
            
            if case .userSelected(color: _) = selectedColor {
                Section {
                    ColorPicker("Select Color", selection: bindingForUserSelectedColor())
                }
            }
        }
        .navigationTitle("Select Indentation Color")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func optionalBindingForUserSelectedColor() -> Binding<Color?> {
        Binding {
            if case let .userSelected(color) = selectedColor,
            let color {
                return color
            } else {
                return nil
            }
        } set: { _ in }
    }
    
    func bindingForUserSelectedColor() -> Binding<Color> {
        Binding {
            if case let .userSelected(color) = selectedColor,
            let color {
                return color
            } else {
                return Color.random
            }
        } set: { value in
            selectedColor = .userSelected(color: value)
        }
    }
}

struct SettingsIndentationUnknownColorView: View {
    var body: some View {
        Image(systemName: "questionmark.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(Color(uiColor: UIColor.systemGray3))
            .frame(width: 25, height: 25)
    }
}

