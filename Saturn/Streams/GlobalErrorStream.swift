//
//  GlobalErrorStream.swift
//  Saturn
//
//  Created by James Eunson on 28/3/2023.
//

import Foundation
import Combine

final class GlobalErrorStream {
    private let errorSubject = PassthroughSubject<Error, Never>()
    public let errorStream: AnyPublisher<Error, Never>
    
    init() {
        self.errorStream = errorSubject.eraseToAnyPublisher()
    }
    
    func addError(_ error: Error) {
        errorSubject.send(error)
    }
}
