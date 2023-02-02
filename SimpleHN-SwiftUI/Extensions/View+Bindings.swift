//
//  View+Bindings.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 2/2/2023.
//

import Foundation
import SwiftUI

extension View {
    func createBoolBinding<T>(from binding: Binding<T?>) -> Binding<Bool> {
        Binding {
            binding.wrappedValue != nil
        } set: { value in
            if !value { binding.wrappedValue = nil }
        }
    }
}

