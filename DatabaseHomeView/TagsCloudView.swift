//
//  TagsCloudView.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

struct TagsCloudView: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    var wrappedTags: [Tag] {
        model.database.popularTags.sorted().map { Tag($0) }
    }

    var body: some View {
        FlowLayout(wrappedTags) { tag in
            Button(action: {
                model.navigateTo(destination: .tags(tag: tag.name))
            }, label: {
                TagView(title: tag.name)
            })
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    TagsCloudView(model: DatabaseHomeViewModel())
}
