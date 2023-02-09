//
//  LayoutManager.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/2/2023.
//

import Foundation
import UIKit

final class LayoutManager {
    static let `default` = LayoutManager()
    
    let statusBarHeight: CGFloat
    
    init() {
        let window = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
        
         statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }
}
