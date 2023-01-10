//
//  NotesTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 19/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

extension NSTextView { // H/T: https://stackoverflow.com/a/54228147/3963806
    var contentSize: CGSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            print("textView no layoutManager or textContainer")
            return .zero
        }

        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size
    }
}

class NotesTableCellView: NSTableCellView, NSTextViewDelegate {
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet var textViewMarkdown: SBDownTextView!

    override func awakeFromNib() {
        super.awakeFromNib()

        textViewMarkdown.refuseFirstResponder = true
        textViewMarkdown.delegate = self
        
        textViewMarkdown.enabledTextCheckingTypes = 0
        textViewMarkdown.isAutomaticQuoteSubstitutionEnabled = false
        textViewMarkdown.isAutomaticTextReplacementEnabled = false
        textViewMarkdown.isAutomaticDashSubstitutionEnabled = false
    }

    override func prepareForReuse() {
        textViewMarkdown.markdownEnabled = false
        textViewMarkdown.string = "<Not Set>"
                
        textViewMarkdown.enabledTextCheckingTypes = 0
        textViewMarkdown.isAutomaticQuoteSubstitutionEnabled = false
        textViewMarkdown.isAutomaticTextReplacementEnabled = false
        textViewMarkdown.isAutomaticDashSubstitutionEnabled = false
    }

    var isSomeTextSelected : Bool {
        return textViewMarkdown.selectedRange().length > 0
    }
    
    func copySelectedText () {
        textViewMarkdown.copy(self)
    }
    
    func setMarkdownOrText(string: String, markdown: Bool = false) {
        textViewMarkdown.markdownEnabled = markdown
        textViewMarkdown.string = string

        if !markdown {
            

            textViewMarkdown.isEditable = true
            textViewMarkdown.checkTextInDocument(nil)
            textViewMarkdown.isEditable = false
        }

        recalculateHeightConstraint()
    }

    func recalculateHeightConstraint() {
        heightConstraint.constant = textViewMarkdown.contentSize.height + 20
    }
}
