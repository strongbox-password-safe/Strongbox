//
//  DSFSecureTextField.swift
//
//  Created by Darren Ford on 2/1/20.
//  Copyright © 2020 Darren Ford. All rights reserved.
//
//  MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights















import AppKit

@IBDesignable
public class DSFSecureTextField: NSSecureTextField {
    
    @IBInspectable
    public dynamic var displayToggleButton: Bool = true {
        didSet {
            updateForPasswordVisibility()
        }
    }

    
    @IBInspectable
    public dynamic var allowShowPassword: Bool = true {
        didSet {
            passwordIsVisible = false
            configureButtonForState()
        }
    }

    
    @objc public dynamic var passwordIsVisible: Bool = false {
        didSet {
            updateForPasswordVisibility()
        }
    }

    
    private var visibilityButton: DSFPasswordButton?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setup()
    }
}



private extension DSFSecureTextField {
    func configureButtonForState() {
        if allowShowPassword, displayToggleButton {
            let button = DSFPasswordButton(frame: NSRect(x: 0, y: 0, width: 16, height: 16))

            visibilityButton = button
            button.action = #selector(visibilityChanged(_:))
            button.target = self
            addSubview(button)

            addConstraint(
                NSLayoutConstraint(
                    item: button, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0
                ))
            addConstraint(
                NSLayoutConstraint(
                    item: button, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0
                ))

            button.addConstraint(
                NSLayoutConstraint(
                    item: button, attribute: .width, relatedBy: .equal, toItem: button, attribute: .height, multiplier: 1, constant: 0
                )
            )

            addConstraint(
                NSLayoutConstraint(
                    item: button, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0
                ))
            addConstraint(
                NSLayoutConstraint(
                    item: button, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: -2
                ))

            button.needsLayout = true
            needsUpdateConstraints = true
        } else {
            visibilityButton?.removeFromSuperview()
            visibilityButton = nil
        }
        window?.recalculateKeyViewLoop()
    }

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        
        passwordIsVisible = false

        configureButtonForState()
        updateForPasswordVisibility()
    }

    

    
    @objc func visibilityChanged(_ sender: NSButton) {
        passwordIsVisible = (sender.state == .on)
    }

    func updateForPasswordVisibility() {
        let str = cell?.stringValue ?? ""

        if window?.firstResponder == currentEditor() {
            
            abortEditing()
        }

        let newCell: NSTextFieldCell!
        let oldCell: NSTextFieldCell = cell as! NSTextFieldCell

        if !displayToggleButton {
            
            if passwordIsVisible {
                newCell = NSTextFieldCell()
                cell = newCell
            } else {
                newCell = NSSecureTextFieldCell()
                cell = newCell
            }
        } else {
            if allowShowPassword {
                newCell = passwordIsVisible ? DSFPlainTextFieldCell() : DSFPasswordTextFieldCell()
                cell = newCell
            } else {
                newCell = NSSecureTextFieldCell()
                cell = newCell
            }
        }

        newCell.isEditable = true
        newCell.placeholderString = oldCell.placeholderString
        newCell.isScrollable = true
        newCell.font = oldCell.font
        newCell.isBordered = oldCell.isBordered
        newCell.isBezeled = oldCell.isBezeled
        newCell.backgroundStyle = oldCell.backgroundStyle
        newCell.bezelStyle = oldCell.bezelStyle
        newCell.drawsBackground = oldCell.drawsBackground

        cell?.stringValue = str

        visibilityButton?.needsLayout = true
        needsUpdateConstraints = true
    }
}



private class DSFPasswordTextFieldCell: NSSecureTextFieldCell {
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        var newRect = rect
        newRect.size.width -= rect.height * 1.25
        super.select(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        var newRect = rect
        newRect.size.width -= rect.height * 1.25
        super.edit(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if drawsBackground {
            NSColor.controlBackgroundColor.setFill()
            cellFrame.fill()
        }

        var newRect = cellFrame
        newRect.size.width -= cellFrame.height * 1.25
        super.drawInterior(withFrame: newRect, in: controlView)
    }
}

private class DSFPlainTextFieldCell: NSTextFieldCell {
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        var newRect = rect
        newRect.size.width -= rect.height * 1.25
        super.select(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        var newRect = rect
        newRect.size.width -= rect.height * 1.25
        super.edit(withFrame: newRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        if drawsBackground {
            NSColor.controlBackgroundColor.setFill()
            cellFrame.fill()
        }

        var newRect = cellFrame
        newRect.size.width -= cellFrame.height * 1.25
        super.drawInterior(withFrame: newRect, in: controlView)
    }
}



private class DSFPasswordButton: NSButton {
    private enum Translation {
        static var toggle: String {
            NSLocalizedString("Toggle password visibility", comment: "Button used to toggle whether the password is shown in the clear or obscured")
        }
    }

    
    
    private var stateObserver: NSKeyValueObservation?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    override var cell: NSCell? {
        get {
            super.cell
        }
        set {
            super.cell = newValue
            updateObserver()
        }
    }

    private func updateObserver() {
        stateObserver = nil
        stateObserver = observe(\.cell!.state, options: [.new]) { [weak self] _, _ in
            self?.stateChanged()
        }
    }

    private func stateChanged() {
        
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        imagePosition = .noImage

        toolTip = Translation.toggle

        
        updateObserver()
    }

    

    private var trackingArea: NSTrackingArea?

    override func layout() {
        super.layout()

        if let e = trackingArea {
            removeTrackingArea(e)
        }

        let opts: NSTrackingArea.Options = [.inVisibleRect, [.mouseMoved, .mouseEnteredAndExited], .activeInKeyWindow]
        let newE = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(newE)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        NSCursor.pointingHand.set()
    }

    override public func mouseEntered(with _: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override public func mouseExited(with _: NSEvent) {
        NSCursor.arrow.set()
    }

    

    override func draw(_: NSRect) {
        let dest = bounds

        let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

        if state == .off {
            let fillColor = NSColor.secondaryLabelColor

            
            let bezierPath = NSBezierPath()
            bezierPath.move(to: NSPoint(x: 25.12, y: 5.21))
            bezierPath.line(to: NSPoint(x: 6.03, y: 24.46))
            bezierPath.curve(to: NSPoint(x: 6.03, y: 25.42), controlPoint1: NSPoint(x: 5.77, y: 24.72), controlPoint2: NSPoint(x: 5.77, y: 25.16))
            bezierPath.curve(to: NSPoint(x: 6.99, y: 25.42), controlPoint1: NSPoint(x: 6.3, y: 25.7), controlPoint2: NSPoint(x: 6.73, y: 25.69))
            bezierPath.line(to: NSPoint(x: 26.06, y: 6.17))
            bezierPath.curve(to: NSPoint(x: 26.06, y: 5.21), controlPoint1: NSPoint(x: 26.34, y: 5.9), controlPoint2: NSPoint(x: 26.36, y: 5.51))
            bezierPath.curve(to: NSPoint(x: 25.12, y: 5.21), controlPoint1: NSPoint(x: 25.79, y: 4.92), controlPoint2: NSPoint(x: 25.38, y: 4.94))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.14, y: 24.73))
            bezierPath.curve(to: NSPoint(x: 31.27, y: 15.08), controlPoint1: NSPoint(x: 25.03, y: 24.73), controlPoint2: NSPoint(x: 31.27, y: 17.37))
            bezierPath.curve(to: NSPoint(x: 25.43, y: 8.27), controlPoint1: NSPoint(x: 31.27, y: 13.72), controlPoint2: NSPoint(x: 29.09, y: 10.59))
            bezierPath.line(to: NSPoint(x: 24.35, y: 9.36))
            bezierPath.curve(to: NSPoint(x: 29.73, y: 15.08), controlPoint1: NSPoint(x: 27.67, y: 11.38), controlPoint2: NSPoint(x: 29.73, y: 14.09))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 23.31), controlPoint1: NSPoint(x: 29.73, y: 16.58), controlPoint2: NSPoint(x: 23.83, y: 23.31))
            bezierPath.curve(to: NSPoint(x: 11.7, y: 22.53), controlPoint1: NSPoint(x: 14.51, y: 23.31), controlPoint2: NSPoint(x: 13.1, y: 23.02))
            bezierPath.line(to: NSPoint(x: 10.54, y: 23.69))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 24.73), controlPoint1: NSPoint(x: 12.28, y: 24.33), controlPoint2: NSPoint(x: 14.07, y: 24.73))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.14, y: 5.43))
            bezierPath.curve(to: NSPoint(x: 1, y: 15.08), controlPoint1: NSPoint(x: 7.33, y: 5.43), controlPoint2: NSPoint(x: 1, y: 12.79))
            bezierPath.curve(to: NSPoint(x: 7.04, y: 21.99), controlPoint1: NSPoint(x: 1, y: 16.45), controlPoint2: NSPoint(x: 3.27, y: 19.64))
            bezierPath.line(to: NSPoint(x: 8.14, y: 20.88))
            bezierPath.curve(to: NSPoint(x: 2.56, y: 15.08), controlPoint1: NSPoint(x: 4.68, y: 18.8), controlPoint2: NSPoint(x: 2.56, y: 15.99))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 6.85), controlPoint1: NSPoint(x: 2.56, y: 13.4), controlPoint2: NSPoint(x: 8.48, y: 6.85))
            bezierPath.curve(to: NSPoint(x: 20.89, y: 7.68), controlPoint1: NSPoint(x: 17.87, y: 6.85), controlPoint2: NSPoint(x: 19.41, y: 7.17))
            bezierPath.line(to: NSPoint(x: 22.04, y: 6.51))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 5.43), controlPoint1: NSPoint(x: 20.25, y: 5.85), controlPoint2: NSPoint(x: 18.31, y: 5.43))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 21.75, y: 12.25))
            bezierPath.line(to: NSPoint(x: 13.32, y: 20.75))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 21.44), controlPoint1: NSPoint(x: 14.17, y: 21.19), controlPoint2: NSPoint(x: 15.13, y: 21.44))
            bezierPath.curve(to: NSPoint(x: 22.47, y: 15.08), controlPoint1: NSPoint(x: 19.63, y: 21.44), controlPoint2: NSPoint(x: 22.47, y: 18.63))
            bezierPath.curve(to: NSPoint(x: 21.75, y: 12.25), controlPoint1: NSPoint(x: 22.47, y: 14.06), controlPoint2: NSPoint(x: 22.21, y: 13.09))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.14, y: 8.71))
            bezierPath.curve(to: NSPoint(x: 9.81, y: 15.08), controlPoint1: NSPoint(x: 12.62, y: 8.71), controlPoint2: NSPoint(x: 9.83, y: 11.61))
            bezierPath.curve(to: NSPoint(x: 10.6, y: 18.13), controlPoint1: NSPoint(x: 9.81, y: 16.19), controlPoint2: NSPoint(x: 10.09, y: 17.24))
            bezierPath.line(to: NSPoint(x: 19.13, y: 9.51))
            bezierPath.curve(to: NSPoint(x: 16.14, y: 8.71), controlPoint1: NSPoint(x: 18.25, y: 9.01), controlPoint2: NSPoint(x: 17.24, y: 8.71))
            bezierPath.close()

            var t = AffineTransform()
            t.scale(dest.width / 33.0)
            t.translate(x: 0, y: 1)
            bezierPath.transform(using: t)

            fillColor.setFill()
            bezierPath.fill()
        } else {
            let fillColor = NSColor.red

            let bezierPath = NSBezierPath()
            bezierPath.move(to: NSPoint(x: 16.01, y: 5))
            bezierPath.curve(to: NSPoint(x: 1, y: 15), controlPoint1: NSPoint(x: 7.27, y: 5), controlPoint2: NSPoint(x: 1, y: 12.63))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 25), controlPoint1: NSPoint(x: 1, y: 17.37), controlPoint2: NSPoint(x: 7.31, y: 25))
            bezierPath.curve(to: NSPoint(x: 31, y: 15), controlPoint1: NSPoint(x: 24.78, y: 25), controlPoint2: NSPoint(x: 31, y: 17.37))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 5), controlPoint1: NSPoint(x: 31, y: 12.63), controlPoint2: NSPoint(x: 24.81, y: 5))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.01, y: 6.47))
            bezierPath.curve(to: NSPoint(x: 29.47, y: 15), controlPoint1: NSPoint(x: 23.59, y: 6.47), controlPoint2: NSPoint(x: 29.47, y: 13.27))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 23.53), controlPoint1: NSPoint(x: 29.47, y: 16.56), controlPoint2: NSPoint(x: 23.59, y: 23.53))
            bezierPath.curve(to: NSPoint(x: 2.54, y: 15), controlPoint1: NSPoint(x: 8.41, y: 23.53), controlPoint2: NSPoint(x: 2.54, y: 16.56))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 6.47), controlPoint1: NSPoint(x: 2.54, y: 13.27), controlPoint2: NSPoint(x: 8.41, y: 6.47))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.01, y: 8.41))
            bezierPath.curve(to: NSPoint(x: 9.73, y: 15), controlPoint1: NSPoint(x: 12.52, y: 8.41), controlPoint2: NSPoint(x: 9.75, y: 11.4))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 21.59), controlPoint1: NSPoint(x: 9.72, y: 18.68), controlPoint2: NSPoint(x: 12.52, y: 21.59))
            bezierPath.curve(to: NSPoint(x: 22.27, y: 15), controlPoint1: NSPoint(x: 19.46, y: 21.59), controlPoint2: NSPoint(x: 22.27, y: 18.68))
            bezierPath.curve(to: NSPoint(x: 16.01, y: 8.41), controlPoint1: NSPoint(x: 22.27, y: 11.4), controlPoint2: NSPoint(x: 19.46, y: 8.41))
            bezierPath.close()
            bezierPath.move(to: NSPoint(x: 16.02, y: 12.9))
            bezierPath.curve(to: NSPoint(x: 18.02, y: 15), controlPoint1: NSPoint(x: 17.11, y: 12.9), controlPoint2: NSPoint(x: 18.02, y: 13.84))
            bezierPath.curve(to: NSPoint(x: 16.02, y: 17.1), controlPoint1: NSPoint(x: 18.02, y: 16.17), controlPoint2: NSPoint(x: 17.11, y: 17.1))
            bezierPath.curve(to: NSPoint(x: 13.99, y: 15), controlPoint1: NSPoint(x: 14.9, y: 17.1), controlPoint2: NSPoint(x: 13.99, y: 16.17))
            bezierPath.curve(to: NSPoint(x: 16.02, y: 12.9), controlPoint1: NSPoint(x: 13.99, y: 13.84), controlPoint2: NSPoint(x: 14.9, y: 12.9))
            bezierPath.close()

            var t = AffineTransform()
            t.scale(dest.width / 33.0)
            t.translate(x: 0, y: 1)
            bezierPath.transform(using: t)

            if !highContrast {
                let sh = NSShadow()
                sh.shadowColor = NSColor.black.withAlphaComponent(0.6)
                sh.shadowOffset = NSSize(width: 1.0, height: -1.0)
                sh.shadowBlurRadius = 1.0
                sh.set()
            }

            fillColor.setFill()
            bezierPath.fill()
        }
    }
}
