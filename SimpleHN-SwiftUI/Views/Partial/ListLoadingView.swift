//
//  ListLoadingView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 26/1/2023.
//

import Foundation
import SwiftUI

struct ListLoadingView: View {
    var body: some View {
        HStack {
            Spacer()
            SpinnerView()
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}
