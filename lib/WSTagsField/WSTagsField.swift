//
//  WSTagsField.swift
//  Whitesmith
//
//  Created by Ricardo Pereira on 12/05/16.
//  Copyright © 2016 Whitesmith. All rights reserved.
//

import UIKit

public struct WSTagAcceptOption: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let `return` = WSTagAcceptOption(rawValue: 1 << 0)
    public static let  comma   = WSTagAcceptOption(rawValue: 1 << 1)
    public static let  space   = WSTagAcceptOption(rawValue: 1 << 2)
}

@objcMembers open class WSTagsField: UIScrollView {

    fileprivate let textField = BackspaceDetectingTextField()

    /// Dedicated text field delegate.
    open weak var textDelegate: UITextFieldDelegate?

    /// Background color for tag view in normal (non-selected) state.
    open override var tintColor: UIColor! {
        didSet {
            tagViews.forEach { $0.tintColor = self.tintColor }
        }
    }

    /// Text color for tag view in normal (non-selected) state.
    open var textColor: UIColor? {
        didSet {
            tagViews.forEach { $0.textColor = self.textColor }
        }
    }

    /// Background color for tag view in normal (selected) state.
    open var selectedColor: UIColor? {
        didSet {
            tagViews.forEach { $0.selectedColor = self.selectedColor }
        }
    }

    /// Text color for tag view in normal (selected) state.
    open var selectedTextColor: UIColor? {
        didSet {
            tagViews.forEach { $0.selectedTextColor = self.selectedTextColor }
        }
    }

    open var delimiter: String = "" {
        didSet {
            tagViews.forEach { $0.displayDelimiter = self.isDelimiterVisible ? self.delimiter : "" }
        }
    }

    open var isDelimiterVisible: Bool = false {
        didSet {
            tagViews.forEach { $0.displayDelimiter = self.isDelimiterVisible ? self.delimiter : "" }
        }
    }

    open var maxHeight: CGFloat = CGFloat.infinity {
        didSet {
            tagViews.forEach { $0.displayDelimiter = self.isDelimiterVisible ? self.delimiter : "" }
        }
    }

    /// Max number of lines of tags can display in WSTagsField before its contents become scrollable. Default value is 0, which means WSTagsField always resize to fit all tags.
    open var numberOfLines: Int = 0 {
        didSet {
            repositionViews()
        }
    }

    /// Whether or not the WSTagsField should become scrollable
    open var enableScrolling: Bool = true

    open var cornerRadius: CGFloat = 3.0 {
        didSet {
            tagViews.forEach { $0.cornerRadius = self.cornerRadius }
        }
    }

    open var borderWidth: CGFloat = 0.0 {
        didSet {
            tagViews.forEach { $0.borderWidth = self.borderWidth }
        }
    }

    open var borderColor: UIColor? {
        didSet {
            if let borderColor = borderColor { tagViews.forEach { $0.borderColor = borderColor } }
        }
    }

    open override var layoutMargins: UIEdgeInsets {
        didSet {
            tagViews.forEach { $0.layoutMargins = self.layoutMargins }
        }
    }

    open var fieldTextColor: UIColor? {
        didSet {
            textField.textColor = fieldTextColor
        }
    }

    @available(iOS 10.0, *)
    open var fieldTextContentType: UITextContentType! {
        set {
            textField.textContentType = newValue
        }
        get {
            return textField.textContentType
        }
    }

    open var placeholder: String = "Tags" {
        didSet {
            updatePlaceholderTextVisibility()
        }
    }

    open var placeholderColor: UIColor? {
        didSet {
            updatePlaceholderTextVisibility()
        }
    }

    open var placeholderFont: UIFont? {
        didSet {
            updatePlaceholderTextVisibility()
        }
    }

    open var placeholderAlwaysVisible: Bool = false {
        didSet {
            updatePlaceholderTextVisibility()
        }
    }

    open var font: UIFont? {
        didSet {
            textField.font = font
            tagViews.forEach { $0.font = self.font }
        }
    }

    open var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            textField.keyboardAppearance = self.keyboardAppearance
            tagViews.forEach {
                $0.keyboardAppearance = self.keyboardAppearance
            }
        }
    }

    open var readOnly: Bool = false {
        didSet {
            unselectAllTagViewsAnimated()
            textField.isEnabled = !readOnly
            repositionViews()
        }
    }

    /// By default, the return key is used to create a tag in the field. You can change it, i.e., to use comma or space key instead.
    open var acceptTagOption: WSTagAcceptOption = .return

    open override var contentInset: UIEdgeInsets {
        didSet {
            repositionViews()
        }
    }

    open var spaceBetweenTags: CGFloat = 2.0 {
        didSet {
            repositionViews()
        }
    }

    open var spaceBetweenLines: CGFloat = 2.0 {
        didSet {
            repositionViews()
        }
    }

    open override var isFirstResponder: Bool {
        guard super.isFirstResponder == false, textField.isFirstResponder == false else {
            return true
        }

        for i in 0..<tagViews.count where tagViews[i].isFirstResponder {
            return true
        }

        return false
    }

    open fileprivate(set) var tags = [WSTag]()
    internal var tagViews = [WSTagView]()

    // MARK: - Events

    /// Called when the text field should return.
    open var onShouldAcceptTag: ((WSTagsField) -> Bool)?

    /// Called when the text field text has changed. You should update your autocompleting UI based on the text supplied.
    open var onDidChangeText: ((WSTagsField, _ text: String?) -> Void)?

    /// Called when a tag has been added. You should use this opportunity to update your local list of selected items.
    open var onDidAddTag: ((WSTagsField, _ tag: String) -> Void)?

    /// Called when a tag has been removed. You should use this opportunity to update your local list of selected items.
    open var onDidRemoveTag: ((WSTagsField, _ tag: String) -> Void)?

    /// Called when a tag has been selected.
    open var onDidSelectTagView: ((WSTagsField, _ tag: WSTagView) -> Void)?

    /// Called when a tag has been unselected.
    open var onDidUnselectTagView: ((WSTagsField, _ tag: WSTagView) -> Void)?

    /// Called before a tag is added to the tag list. Here you return false to discard tags you do not want to allow.
    open var onValidateTag: ((WSTag, [WSTag]) -> Bool)?

    /**
     * Called when the user attempts to press the Return key with text partially typed.
     * @return A Tag for a match (typically the first item in the matching results),
     * or nil if the text shouldn't be accepted.
     */
    open var onVerifyTag: ((WSTagsField, _ text: String) -> Bool)?

    /**
     * Called when the view has updated its own height. If you are
     * not using Autolayout, you should use this method to update the
     * frames to make sure the tag view still fits.
     */
    open var onDidChangeHeightTo: ((WSTagsField, _ height: CGFloat) -> Void)?

    // MARK: - Properties

    fileprivate var oldIntrinsicContentHeight: CGFloat = 0

    fileprivate var estimatedInitialMaxLayoutWidth: CGFloat {
        // Workaround: https://stackoverflow.com/questions/42342402/how-can-i-create-a-view-has-intrinsiccontentsize-just-like-uilabel
        // "So how the system knows the label's width so that it can calculate the height before layoutSubviews"
        // Re: "It calculates it. It asks “around” first by checking the last constraint (if there is one) for width. It asks it subviews (your custom class) for its constrains and then makes the calculations."
        // This is necessary because, while using the WSTagsField in a `UITableViewCell` with a dynamic height, the `intrinsicContentSize` is called first than the `layoutSubviews`, which leads to an unknown view width when AutoLayout is being used.
        if let superview = superview {
            var layoutWidth = superview.frame.width
            for constraint in superview.constraints where constraint.firstItem === self && constraint.secondItem === superview {
                if constraint.firstAttribute == .leading && constraint.secondAttribute == .leading {
                    layoutWidth -= constraint.constant
                }
                if constraint.firstAttribute == .trailing && constraint.secondAttribute == .trailing {
                    layoutWidth += constraint.constant
                }
            }
            return layoutWidth
        }
        else {
            for constraint in constraints where constraint.firstAttribute == .width {
                return constraint.constant
            }
        }

        return 200 //default estimation
    }

    open var preferredMaxLayoutWidth: CGFloat {
        return bounds.width == 0 ? estimatedInitialMaxLayoutWidth : bounds.width
    }

    open override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.size.width,
                      height: min(maxHeight, maxHeightBasedOnNumberOfLines, calculateContentHeight(layoutWidth: preferredMaxLayoutWidth) + contentInset.top + contentInset.bottom))
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return .init(width: size.width, height: calculateContentHeight(layoutWidth: size.width) + contentInset.top + contentInset.bottom)
    }

    // MARK: -
    public override init(frame: CGRect) {
        super.init(frame: frame)
        internalInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        internalInit()
    }

    deinit {
        if #available(iOS 13, *) {
            // Observers should be cleared when NSKeyValueObservation is deallocated.
            // Let's just keep the code for older iOS versions unmodified to make
            // sure we don't break anything.
            layerBoundsObserver = nil
        }
        else {
            if let observer = layerBoundsObserver {
                removeObserver(observer, forKeyPath: "layer.bounds")
                observer.invalidate()
                self.layerBoundsObserver = nil
            }
        }
    }

    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        tagViews.forEach { $0.setNeedsLayout() }
        repositionViews()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        repositionViews()
    }

    /// Take the text inside of the field and make it a Tag.
    open func acceptCurrentTextAsTag() {
        if let currentText = tokenizeTextFieldText(), !isTextFieldEmpty {
            self.addTag(currentText)
        }
    }

    open var isEditing: Bool {
        return self.textField.isEditing
    }

    open func beginEditing() {
        self.textField.becomeFirstResponder()
        self.unselectAllTagViewsAnimated(false)
    }

    open func endEditing() {
        // NOTE: We used to check if .isFirstResponder and then resign first responder, but sometimes we noticed 
        // that it would be the first responder, but still return isFirstResponder=NO. 
        // So always attempt to resign without checking.
        self.textField.resignFirstResponder()
    }

    open override func reloadInputViews() {
        self.textField.reloadInputViews()
    }

    // MARK: - Adding / Removing Tags
    open func addTags(_ tags: [String]) {
        tags.forEach { addTag($0) }
    }

    open func addTags(_ tags: [WSTag]) {
        tags.forEach { addTag($0) }
    }

    open func addTag(_ tag: String) {
        addTag(WSTag(tag))
    }

    open func addTag(_ tag: WSTag) {
        if let onValidateTag = onValidateTag, !onValidateTag(tag, self.tags) {
            return
        }
        else if self.tags.contains(tag) {
            return
        }

        self.tags.append(tag)

        let tagView = WSTagView(tag: tag)
        tagView.font = self.font
        tagView.tintColor = self.tintColor
        tagView.textColor = self.textColor
        tagView.selectedColor = self.selectedColor
        tagView.selectedTextColor = self.selectedTextColor
        tagView.displayDelimiter = self.isDelimiterVisible ? self.delimiter : ""
        tagView.cornerRadius = self.cornerRadius
        tagView.borderWidth = self.borderWidth
        tagView.borderColor = self.borderColor
        tagView.keyboardAppearance = self.keyboardAppearance
        tagView.layoutMargins = self.layoutMargins

        tagView.onDidRequestSelection = { [weak self] tagView in
            self?.selectTagView(tagView, animated: true)
        }

        tagView.onDidRequestDelete = { [weak self] tagView, replacementText in
            // First, refocus the text field
            self?.textField.becomeFirstResponder()
            if (replacementText?.isEmpty ?? false) == false {
                self?.textField.text = replacementText
            }
            // Then remove the view from our data
            if let index = self?.tagViews.firstIndex(of: tagView) {
                self?.removeTagAtIndex(index)
            }
        }

        tagView.onDidInputText = { [weak self] tagView, text in
            if text == "\n" {
                self?.selectNextTag()
            } else {
                self?.textField.becomeFirstResponder()
                self?.textField.text = text
            }
        }

        self.tagViews.append(tagView)
        addSubview(tagView)

        self.textField.text = ""
        onDidAddTag?(self, tag.text)

        // Clearing text programmatically doesn't call this automatically
        onTextFieldDidChange(self.textField)

        updatePlaceholderTextVisibility()
        repositionViews()
    }

    open func removeTag(_ tag: String) {
        removeTag(WSTag(tag))
    }

    open func removeTag(_ tag: WSTag) {
        if let index = self.tags.firstIndex(of: tag) {
            removeTagAtIndex(index)
        }
    }

    open func removeTagAtIndex(_ index: Int) {
        if index < 0 || index >= self.tags.count { return }

        let tagView = self.tagViews[index]
        tagView.removeFromSuperview()
        self.tagViews.remove(at: index)

        let removedTag = self.tags[index]
        self.tags.remove(at: index)
        onDidRemoveTag?(self, removedTag.text)

        updatePlaceholderTextVisibility()
        repositionViews()
    }

    open func removeTags() {
        self.tags.enumerated().reversed().forEach { index, _ in removeTagAtIndex(index) }
    }

    @discardableResult
    open func tokenizeTextFieldText() -> WSTag? {
        let text = self.textField.text?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
        if text.isEmpty == false && (onVerifyTag?(self, text) ?? true) {
            let tag = WSTag(text)
            addTag(tag)

            self.textField.text = ""
            onTextFieldDidChange(self.textField)

            return tag
        }
        return nil
    }

    // MARK: - Actions

    @objc open func onTextFieldDidChange(_ sender: AnyObject) {
        onDidChangeText?(self, textField.text)
    }

    // MARK: - Tag selection

    open func selectNextTag() {
        guard let selectedIndex = tagViews.firstIndex(where: { $0.selected }) else {
            return
        }

        let nextIndex = tagViews.index(after: selectedIndex)
        if nextIndex < tagViews.count {
            tagViews[selectedIndex].selected = false
            tagViews[nextIndex].selected = true
        }
        else {
            textField.becomeFirstResponder()
        }
    }

    open func selectPrevTag() {
        guard let selectedIndex = tagViews.firstIndex(where: { $0.selected }) else {
            return
        }

        let prevIndex = tagViews.index(before: selectedIndex)
        if prevIndex >= 0 {
            tagViews[selectedIndex].selected = false
            tagViews[prevIndex].selected = true
        }
    }

    open func selectTagView(_ tagView: WSTagView, animated: Bool = false) {
        if self.readOnly {
            return
        }

        if tagView.selected {
            tagView.onDidRequestDelete?(tagView, nil)
            return
        }

        tagView.selected = true
        tagViews.filter { $0 != tagView }.forEach {
            $0.selected = false
            onDidUnselectTagView?(self, $0)
        }

        onDidSelectTagView?(self, tagView)
    }

    open func unselectAllTagViewsAnimated(_ animated: Bool = false) {
        tagViews.forEach {
            $0.selected = false
            onDidUnselectTagView?(self, $0)
        }
    }

    // MARK: internal & private properties or methods

    // Reposition tag views when bounds changes.
    fileprivate var layerBoundsObserver: NSKeyValueObservation?

}

// MARK: TextField Properties

extension WSTagsField {

    public var keyboardType: UIKeyboardType {
        get { return textField.keyboardType }
        set { textField.keyboardType = newValue }
    }

    public var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }

    public var spellCheckingType: UITextSpellCheckingType {
        get { return textField.spellCheckingType }
        set { textField.spellCheckingType = newValue }
    }

    public var autocapitalizationType: UITextAutocapitalizationType {
        get { return textField.autocapitalizationType }
        set { textField.autocapitalizationType = newValue }
    }

    public var autocorrectionType: UITextAutocorrectionType {
        get { return textField.autocorrectionType }
        set { textField.autocorrectionType = newValue }
    }

    public var enablesReturnKeyAutomatically: Bool {
        get { return textField.enablesReturnKeyAutomatically }
        set { textField.enablesReturnKeyAutomatically = newValue }
    }

    public var text: String? {
        get { return textField.text }
        set { textField.text = newValue }
    }

    @available(*, deprecated, message: "Use 'inputFieldAccessoryView' instead")
    override open var inputAccessoryView: UIView? {
        return super.inputAccessoryView
    }

    open var inputFieldAccessoryView: UIView? {
        get { return textField.inputAccessoryView }
        set { textField.inputAccessoryView = newValue }
    }

    var isTextFieldEmpty: Bool {
        return textField.text?.isEmpty ?? true
    }

}

// MARK: Private functions

extension WSTagsField {

    fileprivate func internalInit() {
        self.isScrollEnabled = false
        self.showsHorizontalScrollIndicator = false

        textColor = .white
        selectedColor = .gray
        selectedTextColor = .black

        clipsToBounds = true

        textField.backgroundColor = .clear
        textField.autocorrectionType = UITextAutocorrectionType.no
        textField.autocapitalizationType = UITextAutocapitalizationType.none
        textField.spellCheckingType = .no
        textField.delegate = self
        textField.font = font
        textField.textColor = fieldTextColor
        addSubview(textField)

        layerBoundsObserver = self.observe(\.layer.bounds, options: [.old, .new]) { [weak self] sender, change in
            guard change.oldValue?.size.width != change.newValue?.size.width else {
                return
            }
            self?.repositionViews()
        }

        textField.onDeleteBackwards = { [weak self] in
            if self?.readOnly ?? true {
                return
            }

            if self?.isTextFieldEmpty ?? true, let tagView = self?.tagViews.last {
                self?.selectTagView(tagView, animated: true)
                self?.textField.resignFirstResponder()
            }
        }

        textField.addTarget(self, action: #selector(onTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)

        repositionViews()
    }

    fileprivate func calculateContentHeight(layoutWidth: CGFloat) -> CGFloat {
        var totalRect: CGRect = .null
        enumerateItemRects(layoutWidth: layoutWidth) { (_, tagRect: CGRect?, textFieldRect: CGRect?) in
            if let tagRect = tagRect {
                totalRect = tagRect.union(totalRect)
            }
            else if let textFieldRect = textFieldRect {
                totalRect = textFieldRect.union(totalRect)
            }
        }
        return totalRect.height
    }

    fileprivate func enumerateItemRects(layoutWidth: CGFloat, using closure: (_ tagView: WSTagView?, _ tagRect: CGRect?, _ textFieldRect: CGRect?) -> Void) {
        if layoutWidth == 0 {
            return
        }

        let maxWidth: CGFloat = layoutWidth - contentInset.left - contentInset.right
        var curX: CGFloat = 0.0
        var curY: CGFloat = 0.0
        var totalHeight: CGFloat = Constants.STANDARD_ROW_HEIGHT

        // Tag views Rects
        var tagRect = CGRect.null
        for tagView in tagViews {
            tagRect = CGRect(origin: CGPoint.zero, size: tagView.sizeToFit(.init(width: maxWidth, height: 0)))

            if curX + tagRect.width > maxWidth {
                // Need a new line
                curX = 0
                curY += Constants.STANDARD_ROW_HEIGHT + spaceBetweenLines
                totalHeight += Constants.STANDARD_ROW_HEIGHT
            }

            tagRect.origin.x = curX
            // Center our tagView vertically within STANDARD_ROW_HEIGHT
            tagRect.origin.y = curY + ((Constants.STANDARD_ROW_HEIGHT - tagRect.height)/2.0)

            closure(tagView, tagRect, nil)

            curX = tagRect.maxX + self.spaceBetweenTags
        }

        // Always indent TextField by a little bit
        curX += max(0, Constants.TEXT_FIELD_HSPACE - self.spaceBetweenTags)
        var availableWidthForTextField: CGFloat = maxWidth - curX

        if textField.isEnabled {
            var textFieldRect = CGRect.zero
            textFieldRect.size.height = Constants.STANDARD_ROW_HEIGHT

            if availableWidthForTextField < Constants.MINIMUM_TEXTFIELD_WIDTH {
                // If in the future we add more UI elements below the tags,
                // isOnFirstLine will be useful, and this calculation is important.
                // So leaving it set here, and marking the warning to ignore it
                curX = 0 + Constants.TEXT_FIELD_HSPACE
                curY += Constants.STANDARD_ROW_HEIGHT + spaceBetweenLines
                totalHeight += Constants.STANDARD_ROW_HEIGHT
                // Adjust the width
                availableWidthForTextField = maxWidth - curX
            }
            textFieldRect.origin.y = curY
            textFieldRect.origin.x = curX
            textFieldRect.size.width = availableWidthForTextField

            closure(nil, nil, textFieldRect)
        }
    }

    fileprivate func repositionViews() {
        if self.bounds.width == 0 {
            return
        }

        var contentRect: CGRect = .null
        enumerateItemRects(layoutWidth: self.bounds.width) { (tagView: WSTagView?, tagRect: CGRect?, textFieldRect: CGRect?) in
            if let tagRect = tagRect, let tagView = tagView {
                tagView.frame = tagRect
                tagView.setNeedsLayout()
                contentRect = tagRect.union(contentRect)
            }
            else if let textFieldRect = textFieldRect {
                textField.frame = textFieldRect
                contentRect = textFieldRect.union(contentRect)
            }
        }

        textField.isHidden = !textField.isEnabled

        invalidateIntrinsicContentSize()
        let newIntrinsicContentHeight = intrinsicContentSize.height

        if constraints.isEmpty {
            frame.size.height = newIntrinsicContentHeight.rounded()
        }

        if oldIntrinsicContentHeight != newIntrinsicContentHeight {
            if let didChangeHeightToEvent = self.onDidChangeHeightTo {
                didChangeHeightToEvent(self, newIntrinsicContentHeight)
            }
            oldIntrinsicContentHeight = newIntrinsicContentHeight
        }

        if self.enableScrolling {
            self.isScrollEnabled = contentRect.height + contentInset.top + contentInset.bottom >= newIntrinsicContentHeight
        }
        self.contentSize.width = self.bounds.width - contentInset.left - contentInset.right
        self.contentSize.height = contentRect.height

        if self.isScrollEnabled {
            // FIXME: this isn't working. Need to think in a workaround.
            //self.scrollRectToVisible(textField.frame, animated: false)
        }
    }

    fileprivate func updatePlaceholderTextVisibility() {
        textField.attributedPlaceholder = (placeholderAlwaysVisible || tags.count == 0) ? attributedPlaceholder() : nil
    }

    private func attributedPlaceholder() -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any]?
        if let placeholderColor = placeholderColor {
            attributes = [NSAttributedString.Key.foregroundColor: placeholderColor]
        }
        if let placeholderFont = placeholderFont {
            attributes = [NSAttributedString.Key.font: placeholderFont]
        }
        return NSAttributedString(string: placeholder, attributes: attributes)
    }

    private var maxHeightBasedOnNumberOfLines: CGFloat {
        guard self.numberOfLines > 0 else {
            return CGFloat.infinity
        }
        return contentInset.top + contentInset.bottom + Constants.STANDARD_ROW_HEIGHT * CGFloat(numberOfLines) + spaceBetweenLines * CGFloat(numberOfLines - 1)
    }

}

extension WSTagsField: UITextFieldDelegate {

    public func textFieldDidBeginEditing(_ textField: UITextField) {
        textDelegate?.textFieldDidBeginEditing?(textField)
        unselectAllTagViewsAnimated(true)
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        textDelegate?.textFieldDidEndEditing?(textField)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let onShouldAcceptTag = onShouldAcceptTag, !onShouldAcceptTag(self) {
            return false
        }
        if !isTextFieldEmpty, acceptTagOption.contains(.return) {
            tokenizeTextFieldText()
            return true
        }
        return textDelegate?.textFieldShouldReturn?(textField) ?? false
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if acceptTagOption.contains(.comma) && string == "," && onShouldAcceptTag?(self) ?? true {
            tokenizeTextFieldText()
            return false
        }
        if acceptTagOption.contains(.space) && string == " " && onShouldAcceptTag?(self) ?? true {
            tokenizeTextFieldText()
            return false
        }
        return true
    }

}

extension WSTagsField {

    public static func == (lhs: UITextField, rhs: WSTagsField) -> Bool {
        return lhs == rhs.textField
    }

}
