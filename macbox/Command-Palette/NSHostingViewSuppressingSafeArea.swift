//
//  NSHostingViewSuppressingSafeArea.swift
//  MacBox
//
//  Created by Strongbox on 20/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI



class NSHostingViewSuppressingSafeArea<T: View>: NSHostingView<T> {
    required init(rootView: T) {
        super.init(rootView: rootView)

        addLayoutGuide(layoutGuide)

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor),
            topAnchor.constraint(equalTo: layoutGuide.topAnchor),
            trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor),
            bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor),
        ])
    }

    private lazy var layoutGuide = NSLayoutGuide()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaRect: NSRect {
        
        frame
    }

    override var safeAreaInsets: NSEdgeInsets {
        
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override var safeAreaLayoutGuide: NSLayoutGuide {
        
        layoutGuide
    }

    override var additionalSafeAreaInsets: NSEdgeInsets {
        get {
            
            NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }

        set {
            
        }
    }
}
