//
//  StoryListType.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

enum StoryListType: String, CaseIterable, Equatable, StoriesCategoryRow {
    case top = "Top"
    case new = "New"
    case show = "Show"
    case ask = "Ask"
    
    var title: String {
        rawValue
    }
    
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
    
    var httpPath: String {
        switch self {
        case .top:
            return "news"
        case .new:
            return "newest"
        case .show:
            return "show"
        case .ask:
            return "ask"
        }
    }
    
    var cacheKey: String {
        switch self {
        case .top:
            return "topstories"
        case .new:
            return "newstories"
        case .show:
            return "showstories"
        case .ask:
            return "askstories"
        }
    }
    
    var iconName: String {
        switch self {
        case .top:
            return "list.star"
        case .new:
            return "chart.line.uptrend.xyaxis"
        case .show:
            return "binoculars"
        case .ask:
            return "text.bubble"
        }
    }
    
    var subtitle: String? {
        return nil
    }
}

enum StoryExtendedListType: String, CaseIterable, StoriesCategoryRow {
    case best = "Best"
    case front = "Front Page"
    case active = "Active"
    case bestComments = "Best Comments"
    
    var title: String {
        rawValue
    }
    
    var iconName: String {
        switch self {
        case .best:
            return "star"
        case .front:
            return "list.star"
        case .active:
            return "quote.bubble"
        case .bestComments:
            return "star.bubble"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .best:
            return "Highest-voted recent links"
        case .front:
            return "Front page submissions for a given day (e.g. 2016-06-20)"
        case .active:
            return "Most active current discussions"
        case .bestComments:
            return "Highest-voted recent comments"
        }
    }
}

protocol StoriesCategoryRow {
    var title: String { get }
    var subtitle: String? { get }
    var iconName: String { get }
}

