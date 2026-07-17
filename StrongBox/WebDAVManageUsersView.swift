import SwiftUI
import Combine

struct WebDAVManageUsersView: View {
    
    typealias Completion = ((_ usersToRemove: [UserCredential], _ usersToAdd: [UserCredential], _ defaultUserIdentifier: String) -> Void)
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WebDAVManageUsersViewModel
    @State private var isShowingNewUserForm = false
    @State private var newUserUsername = ""
    @State private var newUserPassword = ""
    
    init(viewModel: WebDAVManageUsersViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        #if os(macOS)
        content
            .frame(width: 400, height: 400, alignment: .center)
        #elseif os(iOS)
        content
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    private var content: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                ForEach(viewModel.users) { user in
                    HStack {
                        Text(user.username)
                            .font(.callout)
                        
                        Spacer()
                        
                        if user.id == viewModel.defaultUserIdentifier {
                            Button {
                                
                            } label: {
                                Text("generic_default", comment: "Placeholder indicating default credentials")
                                    .font(.footnote)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(true)
                        } else {
                            HStack(alignment: .center, spacing: 16) {
                                Button {
                                    viewModel.markAsDefault(user: user)
                                } label: {
                                    Text("web_dav_users_set_default_button")
                                        .font(.footnote)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                
                                Button {
                                    viewModel.removeUser(user: user)
                                } label: {
                                    Image(systemName: "trash")
                                        .padding(4)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    
                    Divider()
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("generic_users")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    viewModel.commitChanges()
                    #if os(iOS)
                    dismiss()
                    #endif
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(!viewModel.hasChanges)
                
                Button {
                    toggleNewUserForm(visible: true)
                } label: {
                    Image(systemName: "plus")
                }
                
                #if os(macOS)                
                Button {
                    dismiss()
                } label: {
                    Text("generic_cancel")
                }
                #endif
            }
        }
        .alert("web_dav_new_user_alert_title", isPresented: $isShowingNewUserForm) {
            TextField("generic_fieldname_username", text: $newUserUsername)
                .autocorrectionDisabled()
                .textContentType(.username)
                
            SecureField("generic_fieldname_password", text: $newUserPassword)
                .autocorrectionDisabled()
                .textContentType(.password)
            
            Button("generic_cancel", role: .cancel) {
                toggleNewUserForm(visible: false)
            }
            
            Button("web_dav_test_connection_new_user_alert_button") {
                viewModel.testAndSave(username: newUserUsername, password: newUserPassword)
                toggleNewUserForm(visible: false)
            }
        } message: {
            Text("web_dav_test_connection_new_user_alert_message")
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
    
    private func toggleNewUserForm(visible: Bool, clearInputs: Bool = true) {
        isShowingNewUserForm = visible
        if clearInputs {
            newUserUsername = ""
            newUserPassword = ""
        }
    }
}

struct UserCredential: Identifiable {
    var id: String
    var username: String
    var password: String
    var isDefault: Bool
    
    init(id: String, username: String, password: String = "", isDefault: Bool = false) {
        self.id = id
        self.username = username
        self.password = password
        self.isDefault = isDefault
    }
}

@objc class WebDAVManageUsersViewModel: NSObject, ObservableObject {
    
    @Published private(set) var users: [UserCredential]
    @Published private(set) var defaultUserIdentifier: String
    @Published private(set) var error: Error?
    @Published var showingErrorAlert = false
    
    private(set) var hasChanges = false
    private var usersToAdd = [UserCredential]()
    private var usersToRemove = [UserCredential]()
    
    private var configuration: WebDAVSessionConfiguration
    private var completion: WebDAVManageUsersView.Completion
    private weak var parentController: VIEW_CONTROLLER_PTR?
    
    init(users: [UserCredential] = [],
         configuration: WebDAVSessionConfiguration,
         parentController: VIEW_CONTROLLER_PTR?,
         completion: @escaping WebDAVManageUsersView.Completion) {
        self.users = users
        self.defaultUserIdentifier = users.first { $0.isDefault }?.id ?? ""
        self.configuration = configuration
        self.parentController = parentController
        self.completion = completion
    }
    
    func removeUser(user: UserCredential) {
        users.removeAll { $0.id == user.id }
        usersToAdd.removeAll { $0.id == user.id }
        usersToRemove.append(user)
        updateChanges()
    }
    
    func markAsDefault(user: UserCredential) {
        defaultUserIdentifier = user.id
        updateChanges()
    }
    
    func testAndSave(username: String, password: String) {
        guard let parentController else { return }
        
        Task {
            let configuration = self.configuration
            configuration.username = username
            configuration.password = password
            
            do {
                try await WebDAVStorageProvider.sharedInstance().testConnection(configuration, viewController: parentController)
                
                let newUser = UserCredential(id: UUID().uuidString, username: username, password: password)
                users.append(newUser)
                usersToAdd.append(newUser)
                
                updateChanges()
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    func commitChanges() {
        completion(usersToRemove, usersToAdd, defaultUserIdentifier)
    }
    
    private func updateChanges() {
        let hasNewUsers = !usersToAdd.isEmpty
        let hasRemovedUsers = !usersToRemove.isEmpty
        let hasNewDefaultUser = users.first { $0.isDefault }?.id != defaultUserIdentifier
        hasChanges = hasNewUsers || hasRemovedUsers || hasNewDefaultUser
    }
}
