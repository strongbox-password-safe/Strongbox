//
//  TagsView.swift
//  Strongbox
//
//  Created by Strongbox on 26/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct FlowLayout<Data, RowContent>: View where Data: RandomAccessCollection, RowContent: View, Data.Element: Identifiable, Data.Element: Hashable {
    @State private var height: CGFloat = .zero

    private var data: Data
    private var spacing: CGFloat
    private var rowContent: (Data.Element) -> RowContent

    public init(_ data: Data, spacing: CGFloat = 4, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) {
        self.data = data
        self.spacing = spacing
        self.rowContent = rowContent
    }

    

    private func content(in geometry: GeometryProxy) -> some View {
        var bounds = CGSize.zero

        return ZStack {
            ForEach(data) { item in
                rowContent(item)
                    .padding(.all, spacing)
                    .alignmentGuide(VerticalAlignment.center) { _ in
                        let result = bounds.height

                        if let firstItem = data.last, item == firstItem {
                            bounds.height = 0
                        }
                        return result
                    }
                    .alignmentGuide(HorizontalAlignment.center) { dimension in
                        if abs(bounds.width - dimension.width) > geometry.size.width {
                            bounds.width = 0
                            bounds.height -= dimension.height
                        }

                        let result = bounds.width

                        if let firstItem = data.last, item == firstItem {
                            bounds.width = 0
                        } else {
                            bounds.width -= dimension.width
                        }
                        return result
                    }
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            content(in: geometry)
                .background(viewHeight(for: $height))
        }
        .frame(height: height)
    }

    private func viewHeight(for binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)

            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

struct Tag: Identifiable, Hashable {
    var id: String {
        name
    }

    let name: String

    init(_ name: String) {
        self.name = name
    }
}

struct TagsViewModel {
    let tags: [Tag]

    init(tags: [String]) {
        self.tags = tags.map { Tag($0) }
    }
}

struct TagsView: View {
    var viewModel: TagsViewModel
    var useEasyReadFont: Bool

    var body: some View {
        FlowLayout(viewModel.tags) { tag in
            TagView(title: tag.name, useEasyReadFont: useEasyReadFont)
        }
        .clipped()
    }
}

#Preview {
    let tags = ["Alpha",
                "Beta",
                "Gamma",
                "Delta"]

    let vm = TagsViewModel(tags: tags)

    return TagsView(viewModel: vm, useEasyReadFont: false)
}
