//
//  NextGenWindow.swift
//  MacBox
//
//  Created by Strongbox on 10/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class NextGenWindow: NSWindow {
    override func doCommand(by selector: Selector) {
        

        if selector == NSSelectorFromString("noop:") { 
            if checkEventForCmdNumberDown() {
                return
            }
        }

        super.doCommand(by: selector)
    }

    override func keyDown(with event: NSEvent) {
        

        if checkEventForCmdNumberDown() {
            return
        }

        super.keyDown(with: event)
    }

    func checkEventForCmdNumberDown() -> Bool {
        if let event = currentEvent,
           event.type == .keyDown,
           event.modifierFlags.contains(.command),
           let key = event.charactersIgnoringModifiers?.first?.asciiValue,
           key > 48, key < 58
        {
            let number = key - 48

            

            onCmdPlusNumberPressed(number: Int(number))
            return true
        }

        return false
    }

    func onCmdPlusNumberPressed(number: Int) {
        

        if let group = tabGroup,
           let tabbedWindows,
           number <= tabbedWindows.count
        {
            

            group.selectedWindow = tabbedWindows[number - 1]
        }
    }
}
