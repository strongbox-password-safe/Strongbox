import SwiftUI
import Notelet

@available(iOS 17.0, *)
enum ReleaseNotes {
    
    
    private static var source: [(version: String, items: [NoteletVersionNoteItem])] {
        var whatsNewRows: [NoteletVersionNoteItem.ListRow] = []

        
        
        if !AppPreferences.sharedInstance().disableNetworkBasedFeatures {
            whatsNewRows.append(.init(symbolSystemName: "envelope.badge",
                                      title: "SimpleLogin Aliases",
                                      description: "Generate SimpleLogin email aliases right from the password generator."))
        }

        whatsNewRows.append(contentsOf: [
            .init(symbolSystemName: "person.badge.key",
                  title: "Bitwarden Passkey Import",
                  description: "Bring your Passkeys across from a Bitwarden export."),
            .init(symbolSystemName: "magnifyingglass",
                  title: "Smarter Search",
                  description: "Multi-select actions, a remembered search scope, and password history kept out of your results."),
            .init(symbolSystemName: "paintpalette",
                  title: "Refreshed App Icon",
                  description: "A new liquid glass app icon, with fresh choices in the icon picker."),
        ])

        var fixRows: [NoteletVersionNoteItem.ListRow] = [
            .init(symbolSystemName: "ellipsis.circle",
                  title: "Unified Entry Menus",
                  description: "One consistent context menu everywhere, plus a dedicated View action."),
            .init(symbolSystemName: "tag",
                  title: "Tag Editing",
                  description: "Fixed crashes when editing tags, including on iOS 18."),
            .init(symbolSystemName: "star",
                  title: "Favourites",
                  description: "Favourites open correctly from the Home screen again."),
        ]

        #if SUBSCRIPTIONS
        fixRows.append(.init(symbolSystemName: "checkmark.seal",
                             title: "Subscription Reliability",
                             description: "Fixed renewals occasionally causing a temporary downgrade to free."))
        #endif

        return [
            (
                version: "1.65.0", 
                items: [
                    .list(title: "What's New", rows: whatsNewRows),
                    .list(title: "Fixes & Improvements", rows: fixRows),
                ]
            ),
        ]
    }

    static var notes: [NoteletVersionNotes] {
        source.map { NoteletVersionNotes(version: $0.version, items: $0.items) }
    }

    static var availableVersions: Set<String> { Set(source.map { $0.version }) }

    static let configuration = NoteletConfiguration(
        nextButtonLabel: "Next",
        doneButtonLabel: "Done",
        accentColor: .blue 
    )
}
