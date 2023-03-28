//
//  StoriesListRefreshView.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation
import SwiftUI

struct StoriesListRefreshView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(x: 1.2, y: 1.2, anchor: .center)
                .padding([.leading, .trailing], 30)
                .padding([.top, .bottom], 15)
                .tint(.white)
        }
        .background(.ultraThinMaterial)
        .mask {
            RoundedRectangle(cornerRadius: 10)
        }
        .offset(.init(width: 0, height: 20))
    }
}

struct StoriesListRefreshView_Previews: PreviewProvider {
    static var previews: some View {
        StoriesListRefreshView()
    }
}
