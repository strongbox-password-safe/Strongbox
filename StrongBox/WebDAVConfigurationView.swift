import SwiftUI
import Combine

#if os(iOS)
import UIKit
typealias PlatformTextContentType = UITextContentType
#elseif os(macOS)
import AppKit
typealias PlatformTextContentType = NSTextContentType
#endif

struct WebDAVConfigurationView: View {
    
    enum FocusField {
        case connectionName
        case url
        case username
        case password
    }
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: WebDAVConfigurationViewModel
    @FocusState private var focusedField: FocusField?
    
    #if os(macOS)
    @State private var isShowingManageUsers = false
    #endif
    
    init(viewModel: WebDAVConfigurationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        #if os(macOS)
        content
            .frame(width: 500, height: 500, alignment: .top)
        #elseif os(iOS)
        NavigationView {
            content
                .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
    
    private var content: some View {
        Form {
            Section {
                ConfigurationField(title: "web_dav_connection_name_label",
                                   placeholder: "e.g. My Home Nextcloud",
                                   isSecure: false,
                                   contentType: contentTypeForConnectionNameField,
                                   text: $viewModel.connectionName
                )
                .focused($focusedField, equals: .connectionName)
                
                ConfigurationField(title: "web_dav_server_url_placeholder",
                                   placeholder: "https://my.server.com/folder",
                                   note: "web_dav_server_url_note",
                                   isSecure: false,
                                   contentType: contentTypeForConnectionURLField,
                                   text: $viewModel.rootURL)
                .focused($focusedField, equals: .url)
                
                Toggle("web_dav_server_allow_untrusted", isOn: $viewModel.allowUntrustedCertificate)
                    .foregroundStyle(.secondary)
                    .font(.subheadline.weight(.semibold))
            } footer: {
                if let message = viewModel.validationMesssage {
                    Text(message)
                        .foregroundColor(.red)
                }
            }
            
            if viewModel.userCredentials().isEmpty {
                Section {
                    ConfigurationField(title: "generic_fieldname_username",
                                       placeholder: "admin",
                                       isSecure: false,
                                       contentType: .username,
                                       text: $viewModel.username)
                    .focused($focusedField, equals: .username)
                    
                    ConfigurationField(title: "generic_fieldname_password",
                                       placeholder: "password",
                                       note: "web_dav_connection_password_note",
                                       isSecure: true,
                                       contentType: .password,
                                       text: $viewModel.password)
                    .focused($focusedField, equals: .password)
                    
                    Button {
                        viewModel.testAndSave()
                        focusedField = nil
                    } label: {
                        Text("web_dav_test_connection_button")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canTestAndSaveConnection)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    #if os(iOS)
                    NavigationLink {
                        let viewModel = WebDAVManageUsersViewModel(users: viewModel.userCredentials(),
                                                                   configuration: viewModel.sessionConfiguration(),
                                                                   parentController: viewModel.parentController) { usersToRemove, usersToAdd, defaultIdentifier in
                            self.viewModel.commitChanges(usersToRemove: usersToRemove,
                                                         usersToAdd: usersToAdd,
                                                         defaultCredential: defaultIdentifier)
                        }
                        WebDAVManageUsersView(viewModel: viewModel)
                    } label: {
                        Text("web_dav_manage_users_button")
                    }
                    #elseif os(macOS)
                    Button {
                        isShowingManageUsers = true
                    } label: {
                        Text("web_dav_manage_users_button")
                    }
                    .frame(maxWidth: .infinity)
                    .sheet(isPresented: $isShowingManageUsers) {
                        let viewModel = WebDAVManageUsersViewModel(users: viewModel.userCredentials(),
                                                                   configuration: viewModel.sessionConfiguration(),
                                                                   parentController: viewModel.parentController) { usersToRemove, usersToAdd, defaultIdentifier in
                            self.isShowingManageUsers = false
                            self.viewModel.commitChanges(usersToRemove: usersToRemove,
                                                         usersToAdd: usersToAdd,
                                                         defaultCredential: defaultIdentifier)
                        }
                        WebDAVManageUsersView(viewModel: viewModel)
                    }
                    #endif
                }
                
                Section {
                    Button {
                        viewModel.testAndSave()
                        focusedField = nil
                    } label: {
                        Text("web_dav_test_connection_button")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canTestAndSaveConnection)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
            }
            
            Spacer()
                .listRowBackground(Color.clear)
            
            Text("web_dav_connection_form_footer")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            
            Spacer()
                .listRowBackground(Color.clear)
        }
        .navigationTitle("web_dav_connection_form_title")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    viewModel.onCancel()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .alert(String(localized: "generic_error", comment: "Error"), isPresented: $viewModel.showingErrorAlert) {
            Button(String(localized: "alerts_ok", comment: "OK")) {
                viewModel.showingErrorAlert = false
            }
        } message: {
            let message = viewModel.error?.localizedDescription ?? String(localized: "alerts_unknown_error", comment: "Unknown Error")
            Text(message)
        }
    }
    
    private var contentTypeForConnectionNameField: PlatformTextContentType? {
        if #available(macOS 14.0, iOS 13.0, *) {
            return .name
        } else {
            return nil
        }
    }
    
    private var contentTypeForConnectionURLField: PlatformTextContentType? {
        if #available(macOS 14.0, iOS 13.0, *) {
            return .URL
        } else {
            return nil
        }
    }
}

@objc class WebDAVConfigurationViewModel: NSObject, ObservableObject {
    
    @Published var connectionName = ""
    @Published var rootURL = ""
    @Published var username = ""
    @Published var password = ""
    @Published var allowUntrustedCertificate = false
    @Published var validationMesssage: String? = nil
    @Published var validationMesssageColor = Color.red
    @Published var canTestAndSaveConnection = false
    @Published var error: Error?
    @Published var showingErrorAlert = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    private(set) weak var initialConfiguration: WebDAVSessionConfiguration?
    private(set) weak var parentController: VIEW_CONTROLLER_PTR?
    private(set) var completion: (Bool, WebDAVSessionConfiguration?) -> Void
    
    private var workingCredentials = [WebDAVSessionConfigurationCredential]()
    private var workingSelectedCredentialIdentifier: String?
    
    init(initialConfiguration: WebDAVSessionConfiguration?,
         parentController: VIEW_CONTROLLER_PTR,
         completion: @escaping (Bool, WebDAVSessionConfiguration?) -> Void) {
        self.initialConfiguration = initialConfiguration
        self.parentController = parentController
        self.completion = completion
        
        super.init()
        
        self.loadInitialConfiguration()
        self.configureBindings()
        
        






    }
    
    func onCancel() {
        completion(false, nil)
    }
    
    func commitChanges(usersToRemove: [UserCredential], usersToAdd: [UserCredential], defaultCredential: String) {
        let sessionConfiguration = sessionConfiguration()
        usersToRemove.forEach { credential in
            sessionConfiguration.removeCredential(byIdentifier: credential.id)
        }
        usersToAdd.forEach { credential in
            let newCredentials = WebDAVSessionConfigurationCredential()
            newCredentials.username = credential.username
            newCredentials.password = credential.password
            sessionConfiguration.upsertCredential(newCredentials, setAsSelected: false)
        }
        sessionConfiguration.selectedCredentialIdentifier = defaultCredential
        
        updateWorkingCredentials(with: sessionConfiguration)
    }
    
    func testAndSave() {
        guard let parentController else { return }
        guard let (_, url) = validateConnection() else { return }
        
        if url.pathExtension.count != 0 {
            let title = String(localized: "webdav_vc_validation_url_maybe_invalid", comment: "URL May Be Invalid")
            let message = String(localized: "webdav_vc_validation_url_are_you_sure", comment: "Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.")
            
            #if os(iOS)
            Alerts.yesNo(parentController.presentedViewController ?? parentController, title: title, message: message) { [weak self] confirmed in
                guard let self, confirmed else { return }
                self.checkConnection()
            }
            #elseif os(macOS)
            MacAlerts.yesNo(title, informativeText: message, window: parentController.view.window) { [weak self] confirmed in
                guard let self, confirmed else { return }
                self.checkConnection()
            }
            #endif
        } else {
            checkConnection()
        }
    }
    
    func userCredentials() -> [UserCredential] {
        let credentials: [WebDAVSessionConfigurationCredential]
        if !workingCredentials.isEmpty {
            credentials = workingCredentials
        } else if let initialConfiguration {
            credentials = initialConfiguration.credentials
        } else {
            return []
        }
        
        guard !credentials.isEmpty else { return [] }

        let selectedIdentifier = workingSelectedCredentialIdentifier ?? initialConfiguration?.selectedCredentialIdentifier ?? credentials.first?.identifier

        return credentials.map { credential in
            UserCredential(id: credential.identifier, username: credential.username, isDefault: credential.identifier == selectedIdentifier)
        }
    }
    
    func sessionConfiguration() -> WebDAVSessionConfiguration {
        let name = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = rootURL.trimmingCharacters(in: .whitespacesAndNewlines).urlExtendedParse ?? URL(string: "https://")!
        
        let configuration = WebDAVSessionConfiguration()
        
        if let initialConfiguration {
            configuration.identifier = initialConfiguration.identifier
        }
        
        configuration.name = name
        configuration.host = host
        configuration.allowUntrustedCertificate = allowUntrustedCertificate
        
        let credentialsToCopy: [WebDAVSessionConfigurationCredential]
        let selectedIdentifier: String?
        if !workingCredentials.isEmpty {
            credentialsToCopy = workingCredentials
            selectedIdentifier = workingSelectedCredentialIdentifier
        } else if let initialConfiguration {
            credentialsToCopy = initialConfiguration.credentials
            selectedIdentifier = initialConfiguration.selectedCredentialIdentifier
        } else {
            credentialsToCopy = []
            selectedIdentifier = nil
        }

        for credential in credentialsToCopy {
            let cloned = WebDAVSessionConfigurationCredential(keyChainUuid: credential.keyChainUuid)
            cloned.identifier = credential.identifier
            cloned.username = credential.username
            cloned.password = credential.password
            configuration.upsertCredential(cloned, setAsSelected: credential.identifier == selectedIdentifier)
        }

        if let selectedIdentifier {
            configuration.selectedCredentialIdentifier = selectedIdentifier
        }
        
        return configuration
    }
    
    @discardableResult
    private func validateConnection(updateMessages: Bool = true) -> (name: String, url: URL)? {
        let name = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        var host = rootURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasSuffix("/") {
            host = String(host.dropLast())
        }
        
        let urlHost = host.urlExtendedParse
        
        if name.count == 0 {
            if updateMessages {
                self.validationMesssage = String(localized: "connection_vc_name_invalid", comment: "Please enter a valid name.")
                self.validationMesssageColor = Color.red
            }
            self.canTestAndSaveConnection = false
            return nil
        } else if urlHost == nil || urlHost?.scheme == nil || urlHost?.host == nil {
            if updateMessages {
                self.validationMesssage = String(localized: "webdav_vc_validation_url_invalid", comment: "URL Invalid")
                self.validationMesssageColor = Color.red
            }
            self.canTestAndSaveConnection = false
            return nil
        } else if let urlHost, urlHost.pathExtension.count != 0 {
            if updateMessages {
                self.validationMesssage = String(localized: "webdav_vc_validation_url_are_you_sure", comment: "Are you sure the URL is correct? It should be a URL to a parent folder. Not the database file.")
                self.validationMesssageColor = Color.orange
            }
            self.canTestAndSaveConnection = true
            return (name, urlHost)
        } else if let urlHost {
            self.validationMesssage = ""
            self.canTestAndSaveConnection = true
            return (name, urlHost)
        } else {
            self.validationMesssage = ""
            self.canTestAndSaveConnection = false
            return nil
        }
    }
    
    private func checkConnection() {
        guard let parentController else { return }
        guard let (name, url) = validateConnection() else { return }
        
        let configuration = sessionConfiguration()
        
        if configuration.credentials.isEmpty {
            configuration.username = username
            configuration.password = password
        }
          
        configuration.name = name
        configuration.host = url
        configuration.allowUntrustedCertificate = allowUntrustedCertificate

        Task {
            do {
                try await WebDAVStorageProvider.sharedInstance().testConnection(configuration, viewController: parentController)
                
                await MainActor.run {
                    self.saveAndComplete(configuration: configuration)
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func loadInitialConfiguration() {
        guard let initialConfiguration else { return }
        self.connectionName = initialConfiguration.name ?? ""
        self.rootURL = initialConfiguration.host.absoluteString
        self.allowUntrustedCertificate = initialConfiguration.allowUntrustedCertificate
        self.updateWorkingCredentials(with: initialConfiguration)
    }
    
    private func updateWorkingCredentials(with configuration: WebDAVSessionConfiguration) {
        workingSelectedCredentialIdentifier = configuration.selectedCredentialIdentifier
        workingCredentials = configuration.credentials.map { credential in
            let clone = WebDAVSessionConfigurationCredential(keyChainUuid: credential.keyChainUuid)
            clone.identifier = credential.identifier
            clone.username = credential.username
            clone.password = credential.password
            return clone
        }
    }
    
    private func configureBindings() {
        $connectionName
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                DispatchQueue.main.async {
                    let updateErrorMessages = value.count > 0 && self.rootURL.count > 0
                    self.validateConnection(updateMessages: updateErrorMessages)
                }
        }.store(in: &cancellables)
        
        $rootURL
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                DispatchQueue.main.async {
                    let updateErrorMessages = value.count > 0 && self.connectionName.count > 0
                    self.validateConnection(updateMessages: updateErrorMessages)
                }
        }.store(in: &cancellables)
    }
    
    private func saveAndComplete(configuration: WebDAVSessionConfiguration) {
        self.updateWorkingCredentials(with: configuration)
        self.completion(true, configuration)
    }
}

fileprivate struct ConfigurationField: View {
    
    var title: LocalizedStringKey
    var placeholder: LocalizedStringKey
    var note: LocalizedStringKey? = nil
    var isSecure: Bool
    var contentType: PlatformTextContentType?

    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.secondary)
                    .font(.subheadline.weight(.semibold))
                    #if os(iOS)
                    .padding(.horizontal, 0)
                    #elseif os(macOS)
                    .padding(.horizontal, 10)
                    #endif
                
                ZStack(alignment: .leading) {
                    if isSecure {
                        SecureField("", text: $text)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                            .textContentType(contentType)
                            #if os(macOS)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    } else {
                        TextField("", text: $text)
                            .font(.callout)
                            .multilineTextAlignment(.leading)
                            .textContentType(contentType)
                            #if os(iOS)
                            .textInputAutocapitalization((contentType == .username || contentType == .URL) ? .never : .words)
                            #endif
                            #if os(macOS)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                            .allowsHitTesting(false)
                            #if os(iOS)
                            .padding(.horizontal, 0)
                            #elseif os(macOS)
                            .padding(.horizontal, 18)
                            #endif
                    }
                }
                .frame(height: 40)
                
                #if os(iOS)
                Divider()
                #endif
            }
            
            if let note {
                Text(note)
                    .foregroundStyle(.secondary)
                    .font(Font.footnote.monospacedDigit())
                    .allowsHitTesting(false)
                    #if os(iOS)
                    .padding(.horizontal, 0)
                    #elseif os(macOS)
                    .padding(.horizontal, 8)
                    #endif
            }
        }
        .modifyView { view in
            if #available(iOS 15.0, macOS 13.0, *) {
                view
                    .listRowSeparator(.hidden)
            }
        }
        #if os(macOS)
        .padding(.vertical, 4)
        #endif
    }
}

extension SwiftUIViewFactory {
    @objc static func makeWebDAVConfigurationView(
        initialConfiguration: WebDAVSessionConfiguration?,
        parentController: VIEW_CONTROLLER_PTR,
        completion: @escaping (Bool, WebDAVSessionConfiguration?) -> Void
    ) -> VIEW_CONTROLLER_PTR {
        let viewModel = WebDAVConfigurationViewModel(initialConfiguration: initialConfiguration,
                                                     parentController: parentController,
                                                     completion: completion)
        let view = WebDAVConfigurationView(viewModel: viewModel)
        #if os(iOS)
        let hostingController = UIHostingController(rootView: view)
        return hostingController
        #elseif os(macOS)
        let hostingController = NSHostingController(rootView: view)
        hostingController.preferredContentSize = NSSize(width: 400, height: 400)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }
        return hostingController
        #endif
    }
}

fileprivate extension View {
    func modifyView<Content: View>(
        @ViewBuilder _ transform: (Self) -> Content
    ) -> some View {
        transform(self)
    }
}
