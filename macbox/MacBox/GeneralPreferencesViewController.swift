//
//  GeneralPreferencesViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa
import ServiceManagement
import SwiftUI

@MainActor
class GeneralPreferencesViewController: NSViewController {
    @IBOutlet var stackStartAtLogin: NSStackView!
    @IBOutlet var stackLegacyRegularAppOptions: NSStackView!
    @IBOutlet var buttonStartAtLogin: NSButton!
    @IBOutlet var showInSystemTray: NSButton!
    @IBOutlet var shortcutView: MASShortcutView!
    @IBOutlet var commandPaletteShortcutView: MASShortcutView!
    @IBOutlet var quitWhenAllClosed: NSButton!
    @IBOutlet var checkboxAlwaysShowDockIcon: NSButton!
    @IBOutlet var stackAlwaysShowDockIcon: NSStackView!
    @IBOutlet var passwordGenShortcut: MASShortcutView!

    private lazy var preferencesModel = GeneralPreferencesViewModel(windowProvider: { [weak self] in
        self?.view.window
    })

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("general_settings_tab_title", comment: "General")
        installAppPreferencesHostingView(GeneralPreferencesView(model: preferencesModel))
    }

    @IBAction func onStartAtLogin(_: Any) {
        preferencesModel.setStartAtLoginEnabled(!preferencesModel.startAtLoginEnabled)
    }

    @IBAction func onChanged(_: Any) {
        preferencesModel.scheduleBindUI()
    }
}

@MainActor
private final class GeneralPreferencesViewModel: NSObject, ObservableObject {
    @Published var startAtLoginAvailable = false
    @Published var startAtLoginEnabled = false
    @Published var showSystemTrayIcon = false
    @Published var quitWhenAllClosed = false
    @Published var alwaysShowDockIcon = false
    @Published var showLegacyRegularAppOptions = true
    @Published var showAlwaysShowDockIcon = false

    private let windowProvider: () -> NSWindow?
    private var observerTokens: [NSObjectProtocol] = []
    private var bindUIScheduled = false

    init(windowProvider: @escaping () -> NSWindow?) {
        self.windowProvider = windowProvider
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scheduleBindUI()
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
        bindUIScheduled = false

        let settings = Settings.sharedInstance()

        if #available(macOS 13.0, *) {
            startAtLoginAvailable = true
            refreshStartAtLoginStatus()
        } else {
            startAtLoginAvailable = false
            startAtLoginEnabled = false
        }

        showSystemTrayIcon = settings.showSystemTrayIcon
        quitWhenAllClosed = settings.quitStrongboxOnAllWindowsClosed
        alwaysShowDockIcon = !settings.hideDockIconOnAllMinimized
        showLegacyRegularAppOptions = !settings.showSystemTrayIcon
        showAlwaysShowDockIcon = settings.showSystemTrayIcon
    }

    func scheduleBindUI() {
        guard !bindUIScheduled else {
            return
        }

        bindUIScheduled = true

        DispatchQueue.main.async { [weak self] in
            self?.bindUI()
        }
    }

    func setStartAtLoginEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            scheduleBindUI()
            notifyChanged()
            return
        }

        
        startAtLoginEnabled = enabled

        
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                await self?.presentStartAtLoginError(error)
            }

            await self?.startAtLoginDidChange()
        }
    }

    
    
    @available(macOS 13.0, *)
    private func refreshStartAtLoginStatus() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let enabled = SMAppService.mainApp.status == .enabled
            await self?.applyStartAtLoginStatus(enabled)
        }
    }

    private func applyStartAtLoginStatus(_ enabled: Bool) {
        startAtLoginEnabled = enabled
    }

    private func presentStartAtLoginError(_ error: Error) {
        swlog("Error changing startup item: [%@]", String(describing: error))
        MacAlerts.error(error, window: windowProvider())
    }

    private func startAtLoginDidChange() {
        scheduleBindUI()
        notifyChanged()
    }

    func setShowSystemTrayIcon(_ enabled: Bool) {
        let settings = Settings.sharedInstance()
        guard settings.showSystemTrayIcon != enabled else { return }

        settings.showSystemTrayIcon = enabled
        scheduleBindUI()
        notifyChanged()
    }

    func setQuitWhenAllClosed(_ enabled: Bool) {
        let settings = Settings.sharedInstance()
        guard settings.quitStrongboxOnAllWindowsClosed != enabled else { return }

        settings.quitStrongboxOnAllWindowsClosed = enabled
        scheduleBindUI()
        notifyChanged()
    }

    func setAlwaysShowDockIcon(_ enabled: Bool) {
        let settings = Settings.sharedInstance()
        guard settings.hideDockIconOnAllMinimized == enabled else { return }

        settings.hideDockIconOnAllMinimized = !enabled
        scheduleBindUI()
        notifyChanged()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

private struct GeneralPreferencesView: View {
    @ObservedObject var model: GeneralPreferencesViewModel

    var body: some View {
        AppPreferencesPage {
            AppPreferencesSection(title: NSLocalizedString("general_settings_launch_section_title", comment: "Launch")) {
                if model.startAtLoginAvailable {
                    AppPreferencesToggleRow(
                        title: NSLocalizedString("general_settings_start_at_login_title", comment: "Start at Login"),
                        description: NSLocalizedString("general_settings_start_at_login_description", comment: "Start Strongbox when you login so that your databases are always at your fingertips."),
                        isOn: binding(get: { model.startAtLoginEnabled }, set: model.setStartAtLoginEnabled)
                    )
                }

                AppPreferencesToggleRow(
                    title: NSLocalizedString("general_settings_menu_bar_title", comment: "Keep Strongbox in the Menu Bar"),
                    description: NSLocalizedString("general_settings_menu_bar_description", comment: "Strongbox will always be available in the menu bar even when all databases and windows are closed."),
                    isOn: binding(get: { model.showSystemTrayIcon }, set: model.setShowSystemTrayIcon)
                )

                if model.showAlwaysShowDockIcon {
                    AppPreferencesToggleRow(
                        title: NSLocalizedString("general_settings_always_show_dock_icon_title", comment: "Always Show Dock Icon"),
                        description: NSLocalizedString("general_settings_always_show_dock_icon_description", comment: "Show the dock icon even when there are no open windows."),
                        isOn: binding(get: { model.alwaysShowDockIcon }, set: model.setAlwaysShowDockIcon)
                    )
                }

                if model.showLegacyRegularAppOptions {
                    AppPreferencesToggleRow(
                        title: NSLocalizedString("general_settings_quit_when_all_closed_title", comment: "Quit Strongbox when all closed"),
                        description: NSLocalizedString("general_settings_quit_when_all_closed_description", comment: "Exit the Strongbox process entirely when all windows have been closed."),
                        isOn: binding(get: { model.quitWhenAllClosed }, set: model.setQuitWhenAllClosed)
                    )
                }
            }

            AppPreferencesSection(title: NSLocalizedString("general_settings_global_shortcuts_title", comment: "Global Keyboard Shortcuts")) {
                ShortcutRecorderRow(
                    title: NSLocalizedString("general_settings_show_strongbox_shortcut_title", comment: "Show Strongbox"),
                    userDefaultsKey: NSNotification.Name.preferenceGlobalShowShortcut.rawValue
                )

                ShortcutRecorderRow(
                    title: NSLocalizedString("general_settings_quick_search_shortcut_title", comment: "Quick Search"),
                    userDefaultsKey: kPreferenceLaunchQuickSearchShortcut
                )

                ShortcutRecorderRow(
                    title: NSLocalizedString("popout_password_generator", comment: "Password Generator"),
                    userDefaultsKey: kPreferencePasswordGeneratorShortcut
                )
            }
        }
    }

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    let userDefaultsKey: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 32)

            MASShortcutRecorder(userDefaultsKey: userDefaultsKey)
                .frame(width: 180, height: 22)
        }
        .frame(maxWidth: 640, alignment: .leading)
    }
}

private struct MASShortcutRecorder: NSViewRepresentable {
    let userDefaultsKey: String

    func makeNSView(context _: Context) -> MASShortcutView {
        let view = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 180, height: 22))
        view.associatedUserDefaultsKey = userDefaultsKey
        return view
    }

    func updateNSView(_ nsView: MASShortcutView, context _: Context) {
        if nsView.associatedUserDefaultsKey != userDefaultsKey {
            nsView.associatedUserDefaultsKey = userDefaultsKey
        }
    }
}
