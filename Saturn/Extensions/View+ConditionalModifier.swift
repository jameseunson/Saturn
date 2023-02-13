//
//  View+ConditionalModifier.swift
//  Saturn
//
//  Created by James Eunson on 2/2/2023.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

