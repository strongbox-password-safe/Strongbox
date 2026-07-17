//
//  HeaderWithTextButton.swift
//  MacBox
//
//  Created by Strongbox on 27/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class HeaderWithTextButton: NSTableCellView {
    @IBOutlet var labelHeader: NSTextField!
    @IBOutlet var button: ClickableTextField!
    @IBOutlet var buttonDisclosure: NSButton!

    override func awakeFromNib() {
        buttonDisclosure.isHidden = true
    }

    var onButtonClickedCallback: (() -> Void)?
    var onDisclosureClicked: ((_: Bool) -> Void)?
    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField,
                    onButtonClicked: (() -> Void)? = nil,
                    showDisclosure: Bool = false,
                    disclosureExpanded: Bool = true,
                    onDisclosureClicked: ((Bool) -> Void)? = nil)
    {
        self.field = field

        labelHeader.stringValue = field.name
        button.stringValue = field.value
        button.isHidden = field.value.isEmpty
        buttonDisclosure.isHidden = !showDisclosure
        buttonDisclosure.state = disclosureExpanded ? .on : .off
        updateDisclosureAccessibility(sectionName: field.name,
                                      isExpanded: disclosureExpanded,
                                      showDisclosure: showDisclosure)

        onButtonClickedCallback = onButtonClicked
        self.onDisclosureClicked = onDisclosureClicked

        button.onClick = { [weak self] in
            self?.onClicked()
        }
    }

    func onClicked() {
        

        if let onButtonClickedCallback {
            onButtonClickedCallback()
        }
    }

    @IBAction func onDisclosure(_: Any) {
        onDisclosureClicked?(buttonDisclosure.state == .on)
    }

    private func updateDisclosureAccessibility(sectionName: String, isExpanded: Bool, showDisclosure: Bool) {
        guard showDisclosure else {
            buttonDisclosure.toolTip = nil
            buttonDisclosure.setAccessibilityLabel(nil)
            return
        }

        let formatKey = isExpanded ? "item_details_section_disclosure_collapse_fmt" : "item_details_section_disclosure_expand_fmt"
        let fallbackValue = isExpanded ? "Collapse %@ section" : "Expand %@ section"
        let format = NSLocalizedString(formatKey,
                                       tableName: nil,
                                       bundle: .main,
                                       value: fallbackValue,
                                       comment: "Tooltip and accessibility label for the detail section disclosure button")
        let label = String(format: format, sectionName)
        buttonDisclosure.toolTip = label
        buttonDisclosure.setAccessibilityLabel(label)
    }
}
