//
//  YubiKeyInteractionManager.swift
//  Strongbox
//
//  Created by Strongbox on 02/11/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import UIKit
import YubiKit

@objc
public class YubiKeyInteractionManager: NSObject {
    static var shared = YubiKeyInteractionManager()

    @objc
    public var isYubiKeySupportedOnDevice: Bool {
        false 
    }

    @objc
    public func getChallengeResponse(_: YubiKeyHardwareConfiguration,
                                     _: Data,
                                     _: (_ userCancelled: Bool, _ response: Data?, _ error: Error?) -> Void)
    {
        
        
    }
}
