//
//  BaseUtils.swift
//  Saturn
//
//  Created by James Eunson on 9/1/2023.
//

import Combine
import Foundation

enum LoadableResource<T: Codable> {
    case notLoading
    case loading
    case loaded(response: T)
    case failed
}

enum LoadingState {
    case initialLoad
    case loadingMore
    case loaded
    case failed
}

open class Interactor: ObservableObject {
    var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    var isActive: Bool = false
    func activate() {
        if !isActive {
            isActive = true
            didBecomeActive()
        }
    }
    func didBecomeActive() {}
}
