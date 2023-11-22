//
//  StrongboxCocoaWebKitView.swift
//  test-libcmark-gfm
//
//  Created by Strongbox on 08/11/2023.
//

import Cocoa
import WebKit

class StrongboxCocoaWebKitView: WKWebView, WKNavigationDelegate {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}
