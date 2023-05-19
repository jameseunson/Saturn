//
//  StoriesCategoriesView.swift
//  Saturn
//
//  Created by James Eunson on 19/5/2023.
//

import Foundation
import SwiftUI

struct StoriesCategoriesView: View {
    var body: some View {
        List {
            Section("Categories") {
                ForEach(StoryListType.allCases, id: \.self.cacheKey) { type in
                    NavigationLink {
                        StoriesListView(interactor: StoriesListInteractor(type: type))
                            .navigationTitle(type.rawValue)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    StoriesCategoryMenuView(type: type)
                                }
                            }
                    } label: {
                        makeRowView(row: type)
                    }
                }
            }
            Section("Lists") {
                ForEach(StoryExtendedListType.allCases, id: \.self.rawValue) { type in
                    NavigationLink {
                        Text("Hello world")
                    } label: {
                        makeRowView(row: type)
                    }
                }
            }
        }
    }
    
    func makeRowView(row: StoriesCategoryRow) -> StoriesCategoryRowView {
        StoriesCategoryRowView(config: StoriesCategoryRowViewConfiguration(title: row.title,
                                                                           subtitle: row.subtitle,
                                                                           iconName: row.iconName))
    }
}

struct StoriesListTitleMenuStyle: MenuStyle {
    func makeBody(configuration: MenuStyleConfiguration) -> some View {
        Menu(configuration)
            .foregroundColor(.primary)
            .font(.headline)
    }
}

struct StoriesCategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoriesCategoriesView()
        }
    }
}

struct StoriesCategoryRowView: View {
    let config: StoriesCategoryRowViewConfiguration
    
    var body: some View {
        HStack {
            Image(systemName: config.iconName)
            Spacer().frame(width: 20)
            VStack(alignment: .leading) {
                Text(config.title)
                    .padding([.top, .bottom], config.subtitle == nil ? 8 : 0)
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct StoriesCategoryRowViewConfiguration {
    let title: String
    let subtitle: String?
    let iconName: String
}

struct StoriesCategoryMenuView: View {
    let type: StoryListType
    
    var body: some View {
        Menu {
            ForEach(StoryListType.allCases, id: \.self.cacheKey) { menuType in
                Button {
                    
                } label: {
                    Label {
                        Text(menuType.rawValue)
                    } icon: {
                        if type == menuType {
                            Image(systemName: "checkmark")
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(type.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .menuStyle(StoriesListTitleMenuStyle())
    }
}
