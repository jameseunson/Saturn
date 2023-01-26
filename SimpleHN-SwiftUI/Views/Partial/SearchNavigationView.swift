//
//  SearchNavigationView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct SearchNavigationView: View {
    @Binding var isSearchVisible: Bool
    
    var body: some View {
        NavigationStack {
            SearchView()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            isSearchVisible = false
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
        }
    }
}
