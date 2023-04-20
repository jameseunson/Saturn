//
//  VoteStream.swift
//  Saturn
//
//  Created by James Eunson on 20/4/2023.
//

import Foundation
import Combine

protocol VoteStreaming: AnyObject {
    var voteStream: AnyPublisher<HTMLAPIVote, Never> { get }
    func didVote(_ vote: HTMLAPIVote)
}

final class VoteStream: VoteStreaming {
    private let voteSubject = PassthroughSubject<HTMLAPIVote, Never>()
    public let voteStream: AnyPublisher<HTMLAPIVote, Never>
    
    init() {
        self.voteStream = voteSubject.eraseToAnyPublisher()
    }
    
    func didVote(_ vote: HTMLAPIVote) {
        DispatchQueue.main.async { [weak self] in
            self?.voteSubject.send(vote)
        }
    }
}
