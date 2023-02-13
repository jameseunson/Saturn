//
//  ActivityViewController.swift
//  Saturn
//
//  Created by James Eunson on 9/9/2022.
//

import Foundation
import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    var itemsToShare: [Any]
    var servicesToShareItem: [UIActivity]? = nil
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: itemsToShare, applicationActivities: servicesToShareItem)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

