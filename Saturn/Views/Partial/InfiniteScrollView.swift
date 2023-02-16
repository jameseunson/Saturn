//
//  InfiniteScrollView.swift
//  Saturn
//
//  Created by James Eunson on 17/1/2023.
//
import Foundation
import SwiftUI

protocol InfiniteScrollViewLoading: AnyObject {
    func loadMoreItems()
}

struct InfiniteScrollView<Content>: View where Content: View {
    private let content: Content
    let loader: InfiniteScrollViewLoading
    let requiresLazy: Bool
    
    @State private var offset = CGFloat.zero
    @State private var contentHeight = CGFloat.zero
    
    @Binding private var readyToLoadMore: Bool
    @Binding private var itemsRemainingToLoad: Bool
    
    public init(loader: InfiniteScrollViewLoading, readyToLoadMore: Binding<Bool>, itemsRemainingToLoad: Binding<Bool>, requiresLazy: Bool = true, @ViewBuilder content: () -> Content) {
        self.loader = loader
        self.requiresLazy = requiresLazy
        _readyToLoadMore = readyToLoadMore
        _itemsRemainingToLoad = itemsRemainingToLoad
        self.content = content()
    }
    
    var body : some View {
        ScrollView {
            if requiresLazy {
                LazyVStack(spacing: 0) {
                    content
                }
                .modifier(InfiniteScrollViewModifier(offset: $offset, contentHeight: $contentHeight))
            } else {
                VStack(spacing: 0) {
                    content
                }
                .modifier(InfiniteScrollViewModifier(offset: $offset, contentHeight: $contentHeight))
            }
        }
        .coordinateSpace(name: "scroll")
        .onChange(of: offset, perform: { _ in evaluateLoadMore() })
        .onChange(of: contentHeight, perform: { _ in evaluateLoadMore() })
        .onChange(of: readyToLoadMore) { _ in evaluateLoadMore() }
    }
    
    func evaluateLoadMore() {
        guard itemsRemainingToLoad else {
            return
        }
        guard readyToLoadMore else {
            return
        }
        let adjustedHeight = contentHeight - UIScreen.main.bounds.size.height
        if offset > adjustedHeight {
            loader.loadMoreItems()
            readyToLoadMore = false
        }
    }
}

struct InfiniteScrollViewModifier: ViewModifier {
    @Binding private var offset: CGFloat
    @Binding private var contentHeight: CGFloat
    
    init(offset: Binding<CGFloat>, contentHeight: Binding<CGFloat>) {
        _offset = offset
        _contentHeight = contentHeight
    }
    
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { proxy -> Color in
                DispatchQueue.main.async {
                    offset = -proxy.frame(in: .named("scroll")).origin.y
                    contentHeight = proxy.frame(in: .named("scroll")).size.height
                }
                return Color.clear
            })
    }
}
