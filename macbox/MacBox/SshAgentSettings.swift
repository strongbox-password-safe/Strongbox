//
//  SshAgentSettings.swift
//  MacBox
//
//  Created by Strongbox on 27/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

let template = """
Host *
   IdentityAgent %@
"""

@MainActor
class SshAgentSettings: NSViewController {
    @IBOutlet var textView: NSTextView!
    @IBOutlet var checkboxRunSshAgent: NSButton!
    @IBOutlet var stackSymLink: NSStackView!
    @IBOutlet var stackErrorLaunching: NSStackView!
    @IBOutlet var onLearnMore: ClickableTextField!
    @IBOutlet var comboExpiry: NSPopUpButton!
    @IBOutlet var labelHeaderConfig: NSTextField!
    @IBOutlet var labelSymlnkBody: NSTextField!
    @IBOutlet var buttonCreateSymlink: NSButton!
    @IBOutlet var labelSnippetText: NSTextField!
    @IBOutlet var buttonCopySnippet: NSButton!
    @IBOutlet var stackViewApprovals: NSStackView!
    @IBOutlet var checkboxPreventRapidUnlocks: NSButton!
    @IBOutlet var checkboxAllowUnlockRequests: NSButton!

    private lazy var preferencesModel = SshAgentSettingsViewModel(windowProvider: { [weak self] in
        self?.view.window
    })

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("ssh_agent_settings_title", comment: "SSH Agent")
        installAppPreferencesHostingView(SshAgentSettingsView(model: preferencesModel))
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        preferencesModel.bindUI()
    }

    @IBAction func onSetExpiry(_: Any) {
        preferencesModel.setApprovalExpirySelection(comboExpiry.indexOfSelectedItem)
    }

    @IBAction func onCreateSymLink(_: Any) {
        preferencesModel.createSymlink()
    }

    @IBAction func onToggleSshAgent(_: Any) {
        preferencesModel.setRunSshAgent(checkboxRunSshAgent.state == .on)
    }

    @IBAction func onCopySnippet(_: Any) {
        preferencesModel.copySnippet()
    }

    @IBAction func onPreferenceChanged(_: Any) {
        preferencesModel.setAllowUnlockRequests(checkboxAllowUnlockRequests.state == .on)
        preferencesModel.setPreventRapidUnlocks(checkboxPreventRapidUnlocks.state == .on)
    }

    func bindUi() {
        preferencesModel.bindUI()
    }
}

@MainActor
private final class SshAgentSettingsViewModel: NSObject, ObservableObject {
    @Published var isPro = false
    @Published var showProFeatureBadge = false
    @Published var showProUpsell = false
    @Published var runSshAgent = false
    @Published var isRunning = false
    @Published var showLaunchError = false
    @Published var snippet = ""
    @Published var approvalExpirySelection = 0
    @Published var allowUnlockRequests = false
    @Published var preventRapidUnlocks = false
    @Published var approvals: [SshAgentApprovalDisplayRow] = []
    @Published var signRequests: [SshAgentSignRequestDisplayRow] = []

    private let windowProvider: () -> NSWindow?
    private var observerTokens: [NSObjectProtocol] = []

    var controlsEnabled: Bool {
        isPro
    }

    var agentConfigurationEnabled: Bool {
        isPro && runSshAgent && SSHAgentServer.sharedInstance().socketPathForSshConfig != nil
    }

    var showActivity: Bool {
        isPro && runSshAgent && isRunning
    }

    init(windowProvider: @escaping () -> NSWindow?) {
        self.windowProvider = windowProvider
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )

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
        let pro = settings.isPro

        isPro = pro
        showProFeatureBadge = SettingsProUpsell.isEligibleAudience
        showProUpsell = SettingsProUpsell.shouldShow
        runSshAgent = settings.runSshAgent && pro
        isRunning = SSHAgentServer.sharedInstance().isRunning
        showLaunchError = settings.runSshAgent && pro && !isRunning
        snippet = currentSnippet()
        approvalExpirySelection = selection(for: settings.sshAgentApprovalDefaultExpiryMinutes)
        allowUnlockRequests = settings.sshAgentRequestDatabaseUnlockAllowed
        preventRapidUnlocks = settings.sshAgentPreventRapidRepeatedUnlockRequests
        approvals = SSHAgentRequestHandler.shared.approvals.map(displayRow(for:))
        signRequests = SSHAgentRequestHandler.shared.signRequests.allObjects().reversed().map(displayRow(for:))
    }

    func dismissProUpsell() {
        SettingsProUpsell.dismiss()
        showProUpsell = false
    }

    func setRunSshAgent(_ enabled: Bool) {
        let settings = Settings.sharedInstance()

        guard settings.isPro else {
            bindUI()
            return
        }

        settings.runSshAgent = enabled
        if settings.runSshAgent {
            if !SSHAgentServer.sharedInstance().start() {
                swlog("🔴 Could not start SSH Agent")
            }
        } else {
            SSHAgentServer.sharedInstance().stop()
            SSHAgentRequestHandler.shared.clearAllOfflinePublicKeys()
        }

        bindUI()
        notifyChanged()
    }

    func setApprovalExpirySelection(_ index: Int) {
        Settings.sharedInstance().sshAgentApprovalDefaultExpiryMinutes = SshAgentApprovalExpiryOption(rawValue: index)?.minutes ?? SshAgentApprovalExpiryOption.doNotRemember.minutes
        bindUI()
        notifyChanged()
    }

    func setAllowUnlockRequests(_ enabled: Bool) {
        guard Settings.sharedInstance().sshAgentRequestDatabaseUnlockAllowed != enabled else { return }

        Settings.sharedInstance().sshAgentRequestDatabaseUnlockAllowed = enabled
        bindUI()
        notifyChanged()
    }

    func setPreventRapidUnlocks(_ enabled: Bool) {
        guard Settings.sharedInstance().sshAgentPreventRapidRepeatedUnlockRequests != enabled else { return }

        Settings.sharedInstance().sshAgentPreventRapidRepeatedUnlockRequests = enabled
        bindUI()
        notifyChanged()
    }

    func copySnippet() {
        ClipboardManager.sharedInstance().copyNoneConcealedString(snippet)
    }

    func openLearnMore() {
        NSWorkspace.shared.open(URL(string: "https://strongbox.reamaze.com/articles/ssh-agent")!)
    }

    func createSymlink() {
        MacAlerts.info(
            NSLocalizedString("ssh_agent_symlink_save_title", comment: "Save Symlink"),
            informativeText: NSLocalizedString(
                "ssh_agent_symlink_permission_message",
                comment: "Strongbox needs file permissions to create the symlink. Please click Save in the following save panel."
            ),
            window: windowProvider()
        ) { [weak self] in
            SSHAgentServer.sharedInstance().createSymLink()
            Task { @MainActor [weak self] in
                self?.bindUI()
            }
        }
    }

    private func currentSnippet() -> String {
        if let socketPath = SSHAgentServer.sharedInstance().socketPathForSshConfig {
            return String(format: template, socketPath)
        }

        return NSLocalizedString("ssh_agent_settings_socket_path_error", comment: "Error retrieving Socket Path")
    }

    private func selection(for minutes: Int) -> Int {
        if minutes == -1 {
            return SshAgentApprovalExpiryOption.untilQuit.rawValue
        }

        if minutes == -2 {
            return SshAgentApprovalExpiryOption.doNotRemember.rawValue
        }

        switch minutes / 60 {
        case 4:
            return SshAgentApprovalExpiryOption.fourHours.rawValue
        case 12:
            return SshAgentApprovalExpiryOption.twelveHours.rawValue
        default:
            return SshAgentApprovalExpiryOption.twentyFourHours.rawValue
        }
    }

    private func displayRow(for approval: SSHAgentApproval) -> SshAgentApprovalDisplayRow {
        let approvedUntil: String
        let expiryIdentifier: String
        switch approval.expiry {
        case .immediateDoNotRememberApproval:
            approvedUntil = NSLocalizedString("browse_vc_section_title_expired", comment: "Expired")
            expiryIdentifier = "immediate"
        case let .timed(time: time):
            approvedUntil = (time as NSDate).friendlyDateTimeStringPrecise
            expiryIdentifier = "timed-\(time.timeIntervalSinceReferenceDate.bitPattern)"
        case .quit:
            approvedUntil = NSLocalizedString("ssh_agent_remember_approval_until_strongbox_quits", comment: "until Strongbox quits")
            expiryIdentifier = "quit"
        }

        return SshAgentApprovalDisplayRow(
            id: "\(approval.processName)-\(approval.processId)-\(expiryIdentifier)",
            application: approval.processName,
            approvedUntil: approvedUntil
        )
    }

    private func displayRow(for request: SSHAgentSignRequest) -> SshAgentSignRequestDisplayRow {
        let database = MacDatabasePreferences.getById(request.databaseUuid)
        var keyName = NSLocalizedString("generic_unknown", comment: "Unknown")

        if let database, let unlocked = DatabasesCollection.shared.getUnlocked(uuid: database.uuid), let node = unlocked.getItemBy(request.nodeId) {
            keyName = node.title
        }

        return SshAgentSignRequestDisplayRow(
            id: "\(request.timestamp.timeIntervalSince1970)-\(request.processName ?? "")-\(request.databaseUuid)-\(request.nodeId.uuidString)",
            timestamp: (request.timestamp as NSDate).friendlyDateTimeStringPrecise,
            application: request.processName ?? NSLocalizedString("generic_unknown", comment: "Unknown"),
            database: database?.nickName ?? NSLocalizedString("generic_unknown", comment: "Unknown"),
            key: keyName,
            approved: localizedYesOrNoFromBool(request.approved)
        )
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

private enum SshAgentApprovalExpiryOption: Int, CaseIterable, Identifiable {
    case fourHours
    case twelveHours
    case twentyFourHours
    case untilQuit
    case doNotRemember

    var id: Int {
        rawValue
    }

    var minutes: Int {
        switch self {
        case .fourHours:
            return 4 * 60
        case .twelveHours:
            return 12 * 60
        case .twentyFourHours:
            return 24 * 60
        case .untilQuit:
            return -1
        case .doNotRemember:
            return -2
        }
    }

    var title: String {
        let hoursFormat = NSLocalizedString("generic_for_n_hours_suffix_fmt", comment: "for %@ hours")

        switch self {
        case .fourHours:
            return String(format: hoursFormat, "4")
        case .twelveHours:
            return String(format: hoursFormat, "12")
        case .twentyFourHours:
            return String(format: hoursFormat, "24")
        case .untilQuit:
            return NSLocalizedString("ssh_agent_remember_approval_until_strongbox_quits", comment: "until Strongbox quits")
        case .doNotRemember:
            return NSLocalizedString("generic_do_not_remember", comment: "Do Not Remember")
        }
    }
}

private struct SshAgentApprovalDisplayRow: Identifiable {
    let id: String
    let application: String
    let approvedUntil: String
}

private struct SshAgentSignRequestDisplayRow: Identifiable {
    let id: String
    let timestamp: String
    let application: String
    let database: String
    let key: String
    let approved: String
}

private struct SshAgentSettingsView: View {
    @ObservedObject var model: SshAgentSettingsViewModel
    @State private var presentedActivity: SshAgentActivityPresentation?

    var body: some View {
        AppPreferencesPage {
            if model.showProUpsell {
                StrongboxProUpsellView(variant: .ssh, onDismiss: model.dismissProUpsell)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            AppPreferencesSection(title: NSLocalizedString("ssh_agent_settings_title", comment: "SSH Agent")) {
                Toggle(isOn: binding(get: { model.runSshAgent }, set: model.setRunSshAgent)) {
                    HStack(spacing: 8) {
                        Text(NSLocalizedString("ssh_agent_settings_enable_title", comment: "Enable SSH Agent"))

                        if model.showProFeatureBadge {
                            NewProBadge()
                        }
                    }
                }
                .font(.body)
                .disabled(!model.controlsEnabled)

                AppPreferencesHelpText(text: NSLocalizedString("ssh_agent_settings_description", comment: "SSH Agent runs in the background and allows you to SSH with keys stored in your databases."))

                Button(NSLocalizedString("ssh_agent_settings_learn_more", comment: "Learn more...")) {
                    model.openLearnMore()
                }
                .buttonStyle(.link)

                if model.showLaunchError {
                    Label(NSLocalizedString("ssh_agent_settings_launch_error", comment: "Error: Could not launch SSH Agent"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.body)
                }
            }

            AppPreferencesSection(title: NSLocalizedString("ssh_agent_settings_application_approval_title", comment: "Application Approval")) {
                AppPreferencesHelpText(text: NSLocalizedString("ssh_agent_settings_application_approval_description", comment: "Strongbox will request approval for each new application that requests to use a key. This approval will be remembered for the period specified below."))

                HStack(alignment: .center, spacing: 12) {
                    Text(NSLocalizedString("ssh_agent_settings_remember_approval_title", comment: "Remember approval:"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 32)

                    Picker(
                        NSLocalizedString("ssh_agent_settings_remember_approval_title", comment: "Remember approval:"),
                        selection: binding(get: { model.approvalExpirySelection }, set: model.setApprovalExpirySelection)
                    ) {
                        ForEach(SshAgentApprovalExpiryOption.allCases) { option in
                            Text(option.title)
                                .tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .disabled(!model.controlsEnabled)

                AppPreferencesToggleRow(
                    title: NSLocalizedString("ssh_agent_settings_allow_unlock_requests_title", comment: "Allow Database Unlock Requests"),
                    description: NSLocalizedString("ssh_agent_settings_allow_unlock_requests_description", comment: "If your database containing a requested SSH Key is locked, allow Strongbox to prompt you to Unlock. Otherwise Strongbox will simply deny access to requesting processes."),
                    isOn: binding(get: { model.allowUnlockRequests }, set: model.setAllowUnlockRequests)
                )
                .disabled(!model.controlsEnabled)

                AppPreferencesToggleRow(
                    title: NSLocalizedString("ssh_agent_settings_prevent_rapid_unlocks_title", comment: "Prevent Rapid Repeated Unlock Requests"),
                    description: NSLocalizedString("ssh_agent_settings_prevent_rapid_unlocks_description", comment: "Some processes can spawn multiple simultaneous requests for SSH Keys leading to repeated unlock requests. Strongbox can block these after the first unlock failure."),
                    isOn: binding(get: { model.preventRapidUnlocks }, set: model.setPreventRapidUnlocks)
                )
                .disabled(!model.controlsEnabled)
            }

            AppPreferencesSection(title: NSLocalizedString("ssh_agent_settings_config_snippet_title", comment: "SSH Config Snippet")) {
                AppPreferencesHelpText(text: NSLocalizedString("ssh_agent_settings_config_snippet_description", comment: "The snippet below or similar must be added to your ~/.ssh/config file so that requests for keys go to Strongbox."))

                Text(model.snippet)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.agentConfigurationEnabled ? Color(nsColor: .systemGreen) : .secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                    .clipShape(.rect(cornerRadius: 8))

                HStack {
                    Spacer()

                    SettingsButton(
                        title: NSLocalizedString("ssh_agent_settings_copy_snippet_button", comment: "Copy Snippet"),
                        type: .primary,
                        action: model.copySnippet
                    )
                    .disabled(!model.agentConfigurationEnabled)
                }
            }

            if model.showActivity {
                AppPreferencesSection(title: NSLocalizedString("ssh_agent_settings_activity_title", comment: "Activity")) {
                    HStack(spacing: 12) {
                        SettingsButton(
                            title: NSLocalizedString("ssh_agent_settings_view_approvals_button", comment: "View Approvals"),
                            type: .secondary,
                            action: {
                                model.bindUI()
                                presentedActivity = .approvals
                            }
                        )

                        SettingsButton(
                            title: NSLocalizedString("ssh_agent_settings_view_requests_log_button", comment: "View Requests Log"),
                            type: .secondary,
                            action: {
                                model.bindUI()
                                presentedActivity = .requestsLog
                            }
                        )
                    }
                }
            }
        }
        .sheet(item: $presentedActivity) { activity in
            SshAgentActivitySheet(
                activity: activity,
                approvals: model.approvals,
                signRequests: model.signRequests
            )
        }
    }

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }

    private func binding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<Int> {
        Binding(get: get, set: set)
    }
}

private enum SshAgentActivityPresentation: Identifiable {
    case approvals
    case requestsLog

    var id: String {
        switch self {
        case .approvals:
            return "approvals"
        case .requestsLog:
            return "requestsLog"
        }
    }

    var title: String {
        switch self {
        case .approvals:
            return NSLocalizedString("ssh_agent_settings_current_approvals_title", comment: "Current Approvals")
        case .requestsLog:
            return NSLocalizedString("ssh_agent_settings_signing_requests_log_title", comment: "Signing Requests Log")
        }
    }
}

private struct SshAgentActivitySheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: SshAgentActivityPresentation
    let approvals: [SshAgentApprovalDisplayRow]
    let signRequests: [SshAgentSignRequestDisplayRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(activity.title)
                .font(.title2.weight(.semibold))

            Group {
                switch activity {
                case .approvals:
                    SshAgentApprovalsTable(rows: approvals)
                case .requestsLog:
                    SshAgentRequestLogTable(rows: signRequests)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()

                SettingsButton(
                    title: NSLocalizedString("generic_done", comment: "Done"),
                    type: .primary,
                    action: {
                        dismiss()
                    }
                )
            }
        }
        .padding(20)
        .frame(width: 760, alignment: .leading)
        .frame(height: 460, alignment: .top)
    }
}

private struct SshAgentApprovalsTable: View {
    let rows: [SshAgentApprovalDisplayRow]

    var body: some View {
        PreferenceTable(
            emptyText: NSLocalizedString("ssh_agent_settings_empty_approvals", comment: "No current approvals."),
            columns: [
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_application_column", comment: "Application"), width: nil),
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_approved_until_column", comment: "Approved Until"), width: 190)
            ],
            rows: rows.map { [$0.application, $0.approvedUntil] }
        )
    }
}

private struct SshAgentRequestLogTable: View {
    let rows: [SshAgentSignRequestDisplayRow]

    var body: some View {
        PreferenceTable(
            emptyText: NSLocalizedString("ssh_agent_settings_empty_requests", comment: "No signing requests yet."),
            columns: [
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_timestamp_column", comment: "Timestamp"), width: 170),
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_application_column", comment: "Application"), width: 120),
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_database_column", comment: "Database"), width: 120),
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_key_column", comment: "Key"), width: nil),
                PreferenceTableColumn(title: NSLocalizedString("ssh_agent_settings_approved_column", comment: "Approved"), width: 80)
            ],
            rows: rows.map { [$0.timestamp, $0.application, $0.database, $0.key, $0.approved] }
        )
    }
}

private struct PreferenceTableColumn {
    let title: String
    let width: CGFloat?
}

private struct PreferenceTable: View {
    let emptyText: String
    let columns: [PreferenceTableColumn]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    Text(column.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: column.width, alignment: .leading)
                        .frame(maxWidth: column.width == nil ? .infinity : nil, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))

            if rows.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 12) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, value in
                                    let column = columns[index]

                                    Text(value)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(width: column.width, alignment: .leading)
                                        .frame(maxWidth: column.width == nil ? .infinity : nil, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .font(.body)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}
