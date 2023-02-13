//
//  View+Color.swift
//  Saturn
//
//  Created by James Eunson on 2/2/2023.
//

import Foundation
import SwiftUI

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
