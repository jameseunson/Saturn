//
//  SearchFilterView.swift
//  Saturn
//
//  Created by James Eunson on 12/5/2023.
//

import Foundation
import SwiftUI

struct SearchFilterView: View {
    @Binding var displayingFilter: Bool
    @Binding var selectedFilter: SearchDateFilter
    
    var body: some View {
        HStack {
            Text("Filter")
                .font(.callout)
                .fontWeight(.medium)
            Button {
                displayingFilter = true
            } label: {
                HStack {
                    Text(selectedFilter.rawValue)
                        .font(.callout)
                        .foregroundColor(.gray)
                        .padding(.leading, 10)
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                        .padding(.trailing, 10)
                }
                .frame(height: 33)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.systemGray6))
                }
            }
                
            Spacer()
        }
        .padding(.leading)
        Divider()
            .padding(.leading)
    }
}
