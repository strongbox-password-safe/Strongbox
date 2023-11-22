//
//  SideBarViewNode.swift
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
    let headerNode: HeaderNode?
    let color: NSColor?
    weak var parent: SideBarViewNode? 
    let databaseNodeChildCount: String?

    init(context: NavigationContext,
         title: String,
         image: NSImage,
         parent: SideBarViewNode? = nil,
         children: [SideBarViewNode] = [],
         headerNode: HeaderNode? = nil,
         color: NSColor? = nil,
         databaseNodeChildCount: String? = nil)
    {
        self.context = context
        self.title = title
        self.image = image
        self.parent = parent
        self.children = children
        self.headerNode = headerNode
        self.color = color
        self.databaseNodeChildCount = databaseNodeChildCount
    }

    var allDescendents: [SideBarViewNode] {
        let rec = children.flatMap { child in
            child.allDescendents
        }

        return children + rec
    }
}
