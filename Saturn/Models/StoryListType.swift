//
//  StoryListType.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

enum StoryListType {
    case top
    case new
    case show
    case ask
    
    var path: String {
        switch self {
        case .top:
            return "v0/topstories"
        case .new:
            return "v0/newstories"
        case .show:
            return "v0/showstories"
        case .ask:
            return "v0/askstories"
        }
    }
}
