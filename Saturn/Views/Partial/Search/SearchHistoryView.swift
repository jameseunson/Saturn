//
//  SearchHistoryView.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation
import SwiftUI
import Factory

struct SearchHistoryView: View {
    @Injected(\.settingsManager) private var settingsManager
    
    @State var historyItemToDelete: SettingSearchHistoryItem?
    @State var showClearAllConfirmation = false
    
    let onDeleteSearchHistoryItem: ((SettingSearchHistoryItem) -> Void)
    let onClearSearchHistory: (() -> Void)
    let onSelectSearchHistoryItem: ((SettingSearchHistoryItem) -> Void)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Search History")
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding([.leading])
                Spacer()
                Button {
                    showClearAllConfirmation = true
                } label: {
                    Text("Clear all")
                        .font(.callout)
                        .padding([.trailing])
                        .foregroundColor(.accentColor)
                }
            }
            Divider()
                .padding([.leading])
            
            List {
                ForEach(settingsManager.searchHistory().history, id: \.self) { item in
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                            .padding(.trailing, 5)
                        Text(item.query)
                        Spacer()
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .onTapGesture {
                                historyItemToDelete = item
                            }
                    }
                    .padding([.top, .bottom], 5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectSearchHistoryItem(item)
                    }
                }
            }
            .listStyle(.plain)
        }
        .confirmationDialog("Delete History Item?", isPresented: createBoolBinding(from: $historyItemToDelete), actions: {
            if let item = historyItemToDelete {
                Button(role: .destructive) {
                    onDeleteSearchHistoryItem(item)
                } label: {
                    Text("Delete '\(item.query)'")
                }
            }
        })
        .confirmationDialog("Clear History?", isPresented: $showClearAllConfirmation, actions: {
            Button(role: .destructive) {
                onClearSearchHistory()
            } label: {
                Text("Clear search history")
            }
        })
    }
}
