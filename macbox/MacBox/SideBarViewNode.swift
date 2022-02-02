//
//  File.swift
//  MacBox
//
//  Created by Strongbox on 27/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class SideBarViewNode {
    let context: NavigationContext
    let title: String
    let image: NSImage
    var children: [SideBarViewNode]
    let isHeaderNode: Bool
    let color: NSColor?
    let parent: SideBarViewNode?

    init(context: NavigationContext,
         title: String,
         image: NSImage,
         parent: SideBarViewNode?,
         children: [SideBarViewNode] = [],
         isHeaderNode: Bool = false,
         color: NSColor? = nil)
    {
        self.context = context
        self.title = title
        self.image = image
        self.parent = parent
        self.children = children
        self.isHeaderNode = isHeaderNode
        self.color = color
    }

    var allDescendents: [SideBarViewNode] {
        let rec = children.flatMap { child in
            child.allDescendents
        }

        return children + rec
    }

    var cellIdentifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(rawValue: isHeaderNode ? "HeaderCell" : "DataCell")
    }
}
