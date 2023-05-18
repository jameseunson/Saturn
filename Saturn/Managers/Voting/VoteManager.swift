//
//  VoteManager.swift
//  Saturn
//
//  Created by James Eunson on 30/3/2023.
//

import Foundation
import Factory

protocol VoteManaging: AnyObject {
    func vote(item: Votable, direction: HTMLAPIVoteDirection, shouldUpdate: @escaping (() -> ()))
}

final class VoteManager: VoteManaging {
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.globalErrorStream) private var globalErrorStream
    @Injected(\.voteStream) private var voteStream
    
    private let queue: OperationQueue
    
    init() {
        self.queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
    }
    
    func vote(item: Votable, direction: HTMLAPIVoteDirection, shouldUpdate: @escaping (() -> ())) {
        guard let info = item.vote else {
            self.globalErrorStream.addError(HTMLAPIManagerError.cannotVote)
            return
        }
        let operation = BlockOperation {
            let group = DispatchGroup()
            group.enter()
            
            Task { @MainActor in
                let stateBeforeVote = item.vote?.state
                do {
                    if stateBeforeVote == nil { /// Perform vote in requested direction
                        item.vote?.state = direction
                    } else {
                        if stateBeforeVote == direction { /// Perform unvote
                            item.vote?.state = nil
                        } else {
                            item.vote?.state = direction
                        }
                    }
                    shouldUpdate()
                    
                    if stateBeforeVote == nil { /// Perform vote in requested direction
                        try await self.htmlApiManager.vote(direction: direction, info: info)
                    } else { /// Perform unvote
                        try await self.htmlApiManager.unvote(info: info)
                    }
                    
                    if let updatedVote = item.vote {
                        self.voteStream.didVote(updatedVote)
                    }
                    
                } catch {
                    /// Revert vote
                    item.vote?.state = stateBeforeVote
                    shouldUpdate()
                    
                    self.globalErrorStream.addError(HTMLAPIManagerError.cannotVote)
                }
                group.leave()
            }
            
            /// Ensure that vote operations happen no more frequently than every 3 seconds
            /// This is to avoid hitting the aggressive rate limiting on the backend, which we cannot control
            group.enter()
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                group.leave()
            }
            
            group.wait()
        }
        queue.addOperation(operation)
    }
}
