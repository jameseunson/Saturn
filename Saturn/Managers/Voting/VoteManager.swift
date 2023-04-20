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
    private let htmlApiManager = HTMLAPIManager()
    @Injected(\.globalErrorStream) private var globalErrorStream
    @Injected(\.voteStream) private var voteStream
    
    func vote(item: Votable, direction: HTMLAPIVoteDirection, shouldUpdate: @escaping (() -> ())) {
        guard let info = item.vote else {
            self.globalErrorStream.addError(HTMLAPIManagerError.cannotVote)
            return
        }
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
                    voteStream.didVote(updatedVote)
                }
                
            } catch {
                /// Revert vote
                item.vote?.state = stateBeforeVote
                shouldUpdate()
                
                self.globalErrorStream.addError(HTMLAPIManagerError.cannotVote)
            }
        }
    }
}
