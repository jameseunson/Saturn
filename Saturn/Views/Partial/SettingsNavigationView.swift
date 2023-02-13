//
//  SettingsNavigationView.swift
//  Saturn
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct SettingsNavigationView: View {
    @Binding var isSettingsVisible: Bool
    
    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            isSettingsVisible = false
                        } label: {
                            Text("Done")
                                .fontWeight(.medium)
                        }

                    }
                }
        }
    }
}

