//
//  AppSettingsWindowController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

private enum AppPreferencesLayout {
    static let preferredContentWidth: CGFloat = 705
    static let minimumWindowSize = NSSize(width: 900, height: 420)
}

@objc
class AppSettingsWindowController: NSWindowController {
    @objc
    static let sharedInstance: AppSettingsWindowController = .instantiateFromStoryboard()

    private class func instantiateFromStoryboard() -> AppSettingsWindowController {
        let storyboard = NSStoryboard(name: "AppPreferences", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! AppSettingsWindowController
        return wc
    }

    override public func windowDidLoad() {
        super.windowDidLoad()

        window?.minSize = AppPreferencesLayout.minimumWindowSize
        
        if !StrongboxProductBundle.supportsWiFiSync {
            guard let tabVc = contentViewController as? NSTabViewController else {
                return
            }

            if let wiFiSync = getChildVc(WiFiSyncSettings.self) {
                if let idx = tabVc.children.firstIndex(of: wiFiSync) {
                    tabVc.removeChild(at: idx)
                }
            }
        }
    }

    @objc
    public func showGeneralTab() {
        showTab(GeneralPreferencesViewController.self)
    }

    public func showTab(_ type: (some NSViewController).Type) {
        guard let tabVc = contentViewController as? NSTabViewController,
              let idx = getChildVcIndex(type)
        else {
            return
        }

        tabVc.selectedTabViewItemIndex = idx

        showWindow(nil)
    }

    func getChildVcIndex(_ myType: (some NSViewController).Type) -> Int? {
        guard let tabVc = contentViewController as? NSTabViewController,
              let obj = getChildVc(myType)
        else {
            return nil
        }

        return tabVc.children.firstIndex(of: obj)
    }

    func getChildVc<T: NSViewController>(_: T.Type) -> T? {
        guard let tabVc = contentViewController as? NSTabViewController else {
            return nil
        }

        for chi in tabVc.children {
            if let a = chi as? T {
                return a
            }
        }

        return nil
    }
}



class AppSettingsTabViewController: NSTabViewController {
    @IBOutlet var advancedTabItem: NSTabViewItem!
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let tabViewItem = tabViewItem, let window = self.view.window else { return }
        
        if isAdvancedTab(tabViewItem) {
            compressWindowIfNeeded(window, to: 576)
            return
        }

        if let preferredFrame = preferredWindowFrameForSelectedChild(in: window) {
            resizeWindow(window, to: preferredFrame.size)
        }
    }
    
    private func isAdvancedTab(_ tabViewItem: NSTabViewItem) -> Bool {
        return self.advancedTabItem == tabViewItem
    }
    
    private func preferredWindowFrameForSelectedChild(in window: NSWindow) -> NSRect? {
        let idx = selectedTabViewItemIndex

        guard idx >= 0, idx < children.count else {
            return nil
        }

        let preferredContentSize = children[idx].preferredContentSize
        guard preferredContentSize.width > 0 || preferredContentSize.height > 0 else {
            return nil
        }

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let targetContentRect = NSRect(
            x: 0,
            y: 0,
            width: preferredContentSize.width > 0 ? preferredContentSize.width : contentRect.width,
            height: preferredContentSize.height > 0 ? preferredContentSize.height : contentRect.height
        )

        return window.frameRect(forContentRect: targetContentRect)
    }

    private func compressWindowIfNeeded(_ window: NSWindow, to targetHeight: CGFloat) {
        let height = window.frame.height
                
        if height > targetHeight {
            resizeWindow(window, to: NSSize(width: window.frame.width, height: targetHeight))
        }
    }

    
    private func resizeWindow(_ window: NSWindow, to size: NSSize) {
        let adjustedSize = NSSize(
            width: max(size.width, window.minSize.width),
            height: max(size.height, window.minSize.height)
        )

        guard window.frame.size != adjustedSize else {
            return
        }

        var origin = window.frame.origin
        origin.y += window.frame.height - adjustedSize.height
        let newFrame = NSRect(origin: origin, size: adjustedSize)
        window.setFrame(newFrame, display: true, animate: true)
    }
}

@MainActor
extension NSViewController {
    func installAppPreferencesHostingView<Content: View>(_ rootView: Content, preferredWidth: CGFloat = AppPreferencesLayout.preferredContentWidth) {
        view.subviews.forEach { $0.removeFromSuperview() }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.layoutSubtreeIfNeeded()
        let preferredHeight = max(hostingView.fittingSize.height, view.fittingSize.height)
        preferredContentSize = NSSize(width: preferredWidth, height: preferredHeight)
    }
}

struct AppPreferencesPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AppPreferencesSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        } label: {
            Text(title)
                .font(.headline)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppPreferencesHelpText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AppPreferencesToggleRow: View {
    let title: String
    let description: String
    let isOn: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)
                .font(.body)

            AppPreferencesHelpText(text: description)
        }
    }
}

@MainActor
internal enum SettingsProUpsell {
    private static var decision: SettingsProUpsellDecision {
        let settings = Settings.sharedInstance()

        return SettingsProUpsellDecision(
            isUnifiedFreemiumBundle: MacCustomizationManager.isUnifiedFreemiumBundle,
            hasProEntitlement: settings.isPro,
            hasDismissed: settings.hasDismissedSettingsProUpsells
        )
    }

    static var isEligibleAudience: Bool {
        decision.isEligibleAudience
    }

    static var shouldShow: Bool {
        decision.shouldShow
    }

    static func dismiss() {
        let settings = Settings.sharedInstance()

        guard !settings.hasDismissedSettingsProUpsells else { return }

        settings.hasDismissedSettingsProUpsells = true
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

@MainActor
final class IntegrationsSettingsViewModel: NSObject, ObservableObject {
    @Published var browserAutoFillEnabled = false
    @Published var browserAutoFillStrictSubdomainMatchingEnabled = false
    @Published var isPro = false
    @Published var showProFeatureBadge = false
    @Published var showProUpsell = false
    @Published var showSimpleLogin = false
    @Published var simpleLoginApiKey = ""
    @Published var simpleLoginStatusText = ""
    @Published var simpleLoginStatusColor = NSColor.secondaryLabelColor
    @Published var isVerifyingSimpleLogin = false

    private var persistedSimpleLoginApiKey: String?
    private var observerTokens: [NSObjectProtocol] = []

    override init() {
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: nil) { [weak self] _ in
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

    func setBrowserAutoFillEnabled(_ enabled: Bool) {
        let settings = Settings.sharedInstance()

        guard settings.isPro else {
            browserAutoFillEnabled = false
            return
        }

        guard settings.runBrowserAutoFillProxyServer != enabled else {
            return
        }

        settings.runBrowserAutoFillProxyServer = enabled

        if enabled {
            NativeMessagingManifestInstallHelper.installNativeMessagingHostsFiles()
            AutoFillProxyServer.sharedInstance().start()
        } else {
            AutoFillProxyServer.sharedInstance().stop()
            NativeMessagingManifestInstallHelper.removeNativeMessagingHostsFiles()
        }

        bindUI()
        notifyChanged()
    }

    func setBrowserAutoFillStrictSubdomainMatchingEnabled(_ enabled: Bool) {
        let settings = Settings.sharedInstance()

        guard settings.browserAutoFillStrictSubdomainMatching != enabled else {
            return
        }

        settings.browserAutoFillStrictSubdomainMatching = enabled

        bindUI()
        notifyChanged()
    }

    func verifySimpleLogin() {
        let key = simpleLoginApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            updateSimpleLoginStatus(
                NSLocalizedString("simplelogin_error_empty_key", comment: "Please enter an API key"),
                color: .systemOrange
            )
            return
        }

        simpleLoginApiKey = key
        persistedSimpleLoginApiKey = key
        isVerifyingSimpleLogin = true

        SimpleLoginClient.shared.setApiKey(key)
        updateSimpleLoginStatus(
            NSLocalizedString("generic_loading", comment: "Loading..."),
            color: .secondaryLabelColor
        )

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let info = try await SimpleLoginClient.shared.getUserInfo()
                let status = info.isPremium
                    ? String(format: NSLocalizedString("simplelogin_status_connected_premium_fmt", comment: "Connected — %@ (Premium)"), info.email)
                    : String(format: NSLocalizedString("simplelogin_status_connected_fmt", comment: "Connected — %@"), info.email)

                self.updateSimpleLoginStatus(status, color: .systemGreen)
            } catch {
                let slError = error as? SimpleLoginError ?? .unexpectedResponse
                self.updateSimpleLoginStatus(SimpleLoginClient.localizedErrorMessage(slError), color: .systemRed)
                SimpleLoginClient.shared.setApiKey(nil)
                self.persistedSimpleLoginApiKey = nil
            }

            self.isVerifyingSimpleLogin = false
        }
    }

    func clearSimpleLogin() {
        SimpleLoginClient.shared.setApiKey(nil)
        persistedSimpleLoginApiKey = nil
        simpleLoginApiKey = ""
        isVerifyingSimpleLogin = false
        bindSimpleLoginStatus()
    }

    func dismissProUpsell() {
        SettingsProUpsell.dismiss()
        showProUpsell = false
    }

    private func bindUI() {
        let settings = Settings.sharedInstance()

        isPro = settings.isPro
        showProFeatureBadge = SettingsProUpsell.isEligibleAudience
        showProUpsell = SettingsProUpsell.shouldShow
        browserAutoFillEnabled = settings.isPro && settings.runBrowserAutoFillProxyServer
        browserAutoFillStrictSubdomainMatchingEnabled = settings.browserAutoFillStrictSubdomainMatching
        showSimpleLogin = !settings.disableNetworkBasedFeatures

        let persistedKey = SimpleLoginClient.shared.getApiKey()
        if simpleLoginApiKey.isEmpty || simpleLoginApiKey == (persistedSimpleLoginApiKey ?? "") {
            simpleLoginApiKey = persistedKey ?? ""
        }
        persistedSimpleLoginApiKey = persistedKey

        if !isVerifyingSimpleLogin {
            bindSimpleLoginStatus()
        }
    }

    private func bindSimpleLoginStatus() {
        if SimpleLoginClient.shared.isConfigured {
            updateSimpleLoginStatus(
                NSLocalizedString("simplelogin_status_configured", comment: "API key saved"),
                color: .systemGreen
            )
        } else {
            updateSimpleLoginStatus(
                NSLocalizedString("simplelogin_status_not_configured", comment: "Not configured"),
                color: .secondaryLabelColor
            )
        }
    }

    private func updateSimpleLoginStatus(_ text: String, color: NSColor) {
        simpleLoginStatusText = text
        simpleLoginStatusColor = color
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

@MainActor
final class IntegrationsSettingsViewController: NSViewController {
    
    
    private lazy var viewModel = IntegrationsSettingsViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("integrations_settings_tab_title", comment: "Extensions")
        installAppPreferencesHostingView(IntegrationsSettingsView(model: viewModel))
    }
}

internal struct StrongboxProUpsellView: View {
    let variant: Variant
    let onDismiss: () -> Void

    enum Variant {
        case autofill, ssh, wifisync

        var title: String {
            switch self {
            case .autofill:
                return NSLocalizedString("settings_pro_upsell_autofill_title", comment: "Pro upsell title for browser autofill")
            case .ssh:
                return NSLocalizedString("settings_pro_upsell_ssh_title", comment: "Pro upsell title for SSH Agent")
            case .wifisync:
                return NSLocalizedString("settings_pro_upsell_wifi_sync_title", comment: "Pro upsell title for Wi-Fi Sync")
            }
        }
        var icon: String {
            switch self {
            case .autofill:
                return "rectangle.and.pencil.and.ellipsis"
            case .ssh:
                return "apple.terminal.fill"
            case .wifisync:
                return "wifi"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .foregroundStyle(.white)
                .frame(width: 40)
                .overlay(alignment: .center) {
                    Image(systemName: variant.icon)
                        .font(.title3.weight(.bold))
                        .gradientIfPossible(color: Color.blue)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(variant.title)
                    .foregroundStyle(.white)
                    .font(.headline.weight(.semibold))

                Text(NSLocalizedString("upgrade_body_text", comment: "Upgrade to Strongbox Pro and enjoy all these great features"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SettingsButton(
                title: NSLocalizedString("generic_upgrade_to_pro", comment: "Upgrade to Pro"),
                type: .white,
                action: {
                    NSApplication.shared.sendAction(#selector(AppDelegate.onUpgradeToFullVersion(_:)), to: nil, from: nil)
                }
            )

            Button(action: dismissUpsell) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("generic_dismiss", comment: "Dismiss"))
            .help(NSLocalizedString("generic_dismiss", comment: "Dismiss"))
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background {
            RoundedRectangle(cornerRadius: 14)
                .gradientIfPossible(color: .blue)
        }
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    private func dismissUpsell() {
        withAnimation(.easeOut(duration: 0.18)) {
            onDismiss()
        }
    }
}

private struct IntegrationsSettingsView: View {
    @ObservedObject var model: IntegrationsSettingsViewModel

    private var browserAutoFillBinding: Binding<Bool> {
        Binding(
            get: { model.browserAutoFillEnabled },
            set: { model.setBrowserAutoFillEnabled($0) }
        )
    }

    private var strictSubdomainMatchingBinding: Binding<Bool> {
        Binding(
            get: { model.browserAutoFillStrictSubdomainMatchingEnabled },
            set: { model.setBrowserAutoFillStrictSubdomainMatchingEnabled($0) }
        )
    }

    var body: some View {
        AppPreferencesPage {
            if model.showProUpsell {
                StrongboxProUpsellView(variant: .autofill, onDismiss: model.dismissProUpsell)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            AppPreferencesSection(title: NSLocalizedString("integrations_browser_autofill_title", comment: "Browser AutoFill")) {
                Toggle(isOn: browserAutoFillBinding) {
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("integrations_browser_autofill_toggle_title", comment: "Chrome & Firefox AutoFill Extension"))

                        if model.showProFeatureBadge {
                            NewProBadge()
                        }
                    }
                }
                .disabled(!model.isPro)

                Text(NSLocalizedString("integrations_browser_autofill_description", comment: "Enable browser AutoFill integration for Strongbox, so that you can quickly and securely fill passwords in browsers like Chrome and Firefox."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)








            }

            if model.showSimpleLogin {
                AppPreferencesSection(title: NSLocalizedString("simplelogin_settings_header", comment: "SimpleLogin")) {
                    Text(NSLocalizedString("simplelogin_settings_message", comment: "Enter your SimpleLogin API key from the SimpleLogin dashboard."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    simpleLoginApiKeyField
                        .disabled(model.isVerifyingSimpleLogin)

                    HStack(alignment: .center, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            if model.isVerifyingSimpleLogin {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(model.simpleLoginStatusText)
                                .font(.headline.weight(.medium))
                                .foregroundStyle(Color(nsColor: model.simpleLoginStatusColor))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        SettingsButton(
                            title: NSLocalizedString("simplelogin_verify_button", comment: "Save & Verify"),
                            type: .primary,
                            action: {
                                model.verifySimpleLogin()

                            }
                        )
                        .disabled(model.isVerifyingSimpleLogin)

                        SettingsButton(
                            title: NSLocalizedString("simplelogin_clear_button", comment: "Clear"),
                            type: .secondary,
                            action: {
                                model.clearSimpleLogin()
                            }
                        )
                        .disabled(model.isVerifyingSimpleLogin)
                    }
                }
            }
        }
    }

    private var simpleLoginApiKeyField: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            SecureField(
                NSLocalizedString("simplelogin_api_key_placeholder", comment: "Paste your SimpleLogin API key"),
                text: $model.simpleLoginApiKey
            )
            .textFieldStyle(.plain)
            .font(.title3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.65)
        )
        .clipShape(.rect(cornerRadius: 22))
    }
}

struct NewProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .gradientIfPossible(color: Color.blue)
            )
            .overlay(
                Capsule()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}

struct SettingsButton: View {
    let title: String
    let type: SettingsButtonType
    
    enum SettingsButtonType {
        case primary, secondary, tertiary, white
        
        var textColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .white
            case .tertiary: return .primary
            case .white: return .blue
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return Color("sbSecondaryBlue")
            case .tertiary: return Color("sbWhite")
            case .white: return .white
            }
        }
    }
    
    let action: () -> ()
    
    var body: some View {
        Button(action: {
            action()
        }, label: {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(type.textColor)
                .frame(height: 35)
                .padding(.horizontal)
                .frame(minWidth: 80, alignment: .center)
                .background {
                    Capsule()
                        .gradientIfPossible(color: type.backgroundColor)
                        .sbShadow()
                }
        })
        .buttonStyle(.plain)
    }
}


extension View {
    func gradientIfPossible(color: Color) -> some View {
        self
            .modify { view in
                if #available(macOS 13, *) {
                    view.foregroundStyle(color.gradient)
                } else {
                    view.foregroundStyle(color)
                }
            }
    }
    
    @ViewBuilder
    func sbShadow() -> some View {
        self
            .shadow(color: (Color("shadowGrey")).opacity(0.2), radius: 4)
    }
    
    
    func modify<Content: View>(
        @ViewBuilder _ transform: (Self) -> Content
    ) -> some View {
        transform(self)
    }
}
