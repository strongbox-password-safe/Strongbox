//
//  NoClippingView.swift
//  MacBox
//
//  Created by Strongbox on 27/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class NoClippingLayer: CALayer {
    override var masksToBounds: Bool {
        set {}
        get {
            return false
        }
    }
}

class NoClippingView: NSView {
    override var wantsDefaultClipping: Bool {
        return false
    }
    
    override func makeBackingLayer() -> CALayer {
        return NoClippingLayer()
        
    }
}
