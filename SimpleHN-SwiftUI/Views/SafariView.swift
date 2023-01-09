//
//  SafariView.swift
//  Shutterbug
//
//  Created by James Eunson on 15/9/2022.
//

import Foundation
import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Color.accentColor)
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {}
}
