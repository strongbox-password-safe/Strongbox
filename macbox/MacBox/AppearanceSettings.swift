//
//  AppearanceSettings.swift
//  MacBox
//
//  Created by Strongbox on 31/10/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

@MainActor
class AppearanceSettings: NSViewController {
    @IBOutlet var markdown: NSButton!
    @IBOutlet var colorizePasswords: NSButton!
    @IBOutlet var showCopyFieldsButton: NSButton!
    @IBOutlet var showManagerOnAllClosed: NSButton!
    @IBOutlet var hideManagerAfterLaunching: NSButton!
    @IBOutlet var showManagerOnAppLaunch: NSButton!
    @IBOutlet var popupAppearance: NSPopUpButton!

    private let preferencesModel = AppearanceSettingsViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("appearance_settings_tab_title", comment: "Appearance")
        installAppPreferencesHostingView(AppearanceSettingsView(model: preferencesModel))
    }

    @IBAction func onChanged(_: Any) {
        preferencesModel.bindUI()
    }
}

@MainActor
private final class AppearanceSettingsViewModel: NSObject, ObservableObject {
    @Published var appearanceIndex: UInt = 0
    @Published var markdownNotes = false
    @Published var colorizePasswords = false
    @Published var showCopyFieldButton = false
    @Published var closeManagerOnLaunch = false
    @Published var showDatabasesManagerOnAppLaunch = false

    private var observerTokens: [NSObjectProtocol] = []

    override init() {
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func bindUI() {
        let settings = Settings.sharedInstance()

        appearanceIndex = settings.appAppearance.rawValue
        markdownNotes = settings.markdownNotes
        colorizePasswords = settings.colorizePasswords
        showCopyFieldButton = settings.showCopyFieldButton
        closeManagerOnLaunch = settings.closeManagerOnLaunch
        showDatabasesManagerOnAppLaunch = settings.showDatabasesManagerOnAppLaunch
    }

    func setAppearanceIndex(_ index: UInt) {
        let appearance = AppAppearance(rawValue: index)
        let settings = Settings.sharedInstance()

        guard settings.appAppearance != appearance else { return }

        settings.appAppearance = appearance

        if appearance == kAppAppearanceSystem {
            NSApp.appearance = nil
        } else {
            NSApp.appearance = appearance == kAppAppearanceLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }

        bindUI()
        notifyChanged()
    }

    func setMarkdownNotes(_ enabled: Bool) {
        set(enabled, keyPath: \.markdownNotes, setter: { Settings.sharedInstance().markdownNotes = $0 })
    }

    func setColorizePasswords(_ enabled: Bool) {
        set(enabled, keyPath: \.colorizePasswords, setter: { Settings.sharedInstance().colorizePasswords = $0 })
    }

    func setShowCopyFieldButton(_ enabled: Bool) {
        set(enabled, keyPath: \.showCopyFieldButton, setter: { Settings.sharedInstance().showCopyFieldButton = $0 })
    }

    func setCloseManagerOnLaunch(_ enabled: Bool) {
        set(enabled, keyPath: \.closeManagerOnLaunch, setter: { Settings.sharedInstance().closeManagerOnLaunch = $0 })
    }

    func setShowDatabasesManagerOnAppLaunch(_ enabled: Bool) {
        set(enabled, keyPath: \.showDatabasesManagerOnAppLaunch, setter: { Settings.sharedInstance().showDatabasesManagerOnAppLaunch = $0 })
    }

    private func set(_ enabled: Bool, keyPath: KeyPath<AppearanceSettingsViewModel, Bool>, setter: (Bool) -> Void) {
        guard self[keyPath: keyPath] != enabled else { return }

        setter(enabled)
        bindUI()
        notifyChanged()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var model: AppearanceSettingsViewModel
    @State private var showingMarkdownHelp = false

    private var appearanceBinding: Binding<UInt> {
        Binding(
            get: { model.appearanceIndex },
            set: { model.setAppearanceIndex($0) }
        )
    }

    var body: some View {
        AppPreferencesPage {
            AppPreferencesSection(title: NSLocalizedString("appearance_settings_interface_section_title", comment: "Interface")) {
                HStack(alignment: .center, spacing: 12) {
                    Text(NSLocalizedString("appearance_settings_mode_title", comment: "Appearance (Light / Dark)"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 32)

                    Picker(
                        NSLocalizedString("appearance_settings_mode_title", comment: "Appearance (Light / Dark)"),
                        selection: appearanceBinding
                    ) {
                        Text(NSLocalizedString("app_appearance_mode_system", comment: "System"))
                            .tag(kAppAppearanceSystem.rawValue)
                        Text(NSLocalizedString("app_appearance_mode_light", comment: "Light"))
                            .tag(kAppAppearanceLight.rawValue)
                        Text(NSLocalizedString("app_appearance_mode_dark", comment: "Dark"))
                            .tag(kAppAppearanceDark.rawValue)
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    .pickerStyle(.segmented)
                    .padding(.trailing)
                }
                .frame(maxWidth: 640, alignment: .leading)

                HStack(alignment: .center, spacing: 6) {
                    Toggle(NSLocalizedString("appearance_settings_markdown_notes_title", comment: "Markdown Notes"), isOn: binding(get: { model.markdownNotes }, set: model.setMarkdownNotes))

                    Button {
                        showingMarkdownHelp.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("appearance_settings_markdown_help_title", comment: "What is Markdown?"))
                    .popover(isPresented: $showingMarkdownHelp) {
                        MarkdownHelpPopover()
                    }
                }

                Toggle(NSLocalizedString("appearance_settings_colorize_passwords_title", comment: "Colorize Passwords"), isOn: binding(get: { model.colorizePasswords }, set: model.setColorizePasswords))

                Toggle(NSLocalizedString("appearance_settings_show_copy_buttons_title", comment: "Show Copy Buttons on Details Panel"), isOn: binding(get: { model.showCopyFieldButton }, set: model.setShowCopyFieldButton))
            }

            AppPreferencesSection(title: NSLocalizedString("appearance_settings_database_manager_section_title", comment: "Databases Manager")) {
                AppPreferencesHelpText(text: NSLocalizedString("appearance_settings_database_manager_description", comment: "Control when the Databases Manager window is shown or hidden."))

                Toggle(NSLocalizedString("appearance_settings_show_at_startup_title", comment: "Show at Startup"), isOn: binding(get: { model.showDatabasesManagerOnAppLaunch }, set: model.setShowDatabasesManagerOnAppLaunch))

                Toggle(NSLocalizedString("appearance_settings_hide_after_launching_title", comment: "Hide after Launching Database"), isOn: binding(get: { model.closeManagerOnLaunch }, set: model.setCloseManagerOnLaunch))
            }
        }
    }

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }
}

private struct MarkdownHelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("appearance_settings_markdown_help_title", comment: "What is Markdown?"))
                .font(.headline)

            Text(NSLocalizedString("appearance_settings_markdown_help_message", comment: "Markdown is a simple way to add style to your notes. You can have formatting like headers, lists, blockquotes and other useful styles."))
                .fixedSize(horizontal: false, vertical: true)

            Link(
                NSLocalizedString("appearance_settings_markdown_help_link", comment: "Markdown Guide"),
                destination: URL(string: "https://www.markdownguide.org/getting-started")!
            )
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
    }
}
