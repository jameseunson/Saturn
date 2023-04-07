//
//  LayoutManager.swift
//  Saturn
//
//  Created by James Eunson on 9/2/2023.
//

import Foundation
import UIKit

protocol LayoutManaging: AnyObject {
    var statusBarHeight: CGFloat { get }
}

final class LayoutManager: LayoutManaging {
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
