//
//  GlobalErrorStream.swift
//  Saturn
//
//  Created by James Eunson on 28/3/2023.
//

import Foundation
import Combine

protocol GlobalErrorStreaming: AnyObject {
    var errorStream: AnyPublisher<Error, Never> { get }
    func addError(_ error: Error)
}

final class GlobalErrorStream: GlobalErrorStreaming {
    private let errorSubject = PassthroughSubject<Error, Never>()
    public let errorStream: AnyPublisher<Error, Never>
    
    init() {
        self.errorStream = errorSubject.eraseToAnyPublisher()
    }
    
    func addError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorSubject.send(error)
        }
    }
}
