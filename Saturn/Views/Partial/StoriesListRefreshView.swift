//
//  StoriesListRefreshView.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation
import SwiftUI

struct StoriesListRefreshView: View {
    var type: StoriesListRefreshViewType = .refreshing
    
    var body: some View {
        HStack {
            switch type {
            case .refreshing:
                ProgressView()
                    .scaleEffect(x: 1.2, y: 1.2, anchor: .center)
                    .padding([.leading, .trailing], 30)
                    .padding([.top, .bottom], 15)
                    .tint(.white)
                
            case .prompt(let onTapRefreshButton):
                Button {
                    onTapRefreshButton()
                    
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .padding([.leading], 30)
                        .foregroundColor(.white)
                    Text("Refresh")
                        .padding([.trailing], 30)
                        .padding([.top, .bottom], 15)
                        .foregroundColor(.white)
                }
            }
        }
        .background(.ultraThinMaterial)
        .mask {
            RoundedRectangle(cornerRadius: 10)
        }
        .offset(.init(width: 0, height: 20))
    }
}

enum StoriesListRefreshViewType {
    case refreshing
    case prompt(onTapRefreshButton: (() -> Void))
}

struct StoriesListRefreshView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesListRefreshView(type: .refreshing)
    }
}
