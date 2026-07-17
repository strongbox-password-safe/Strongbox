import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CreditCardEditorView: View {
    
    @StateObject private var viewModel: CreditCardEditorViewModel
    @State private var newCustomFieldKey = ""
    @State private var newCustomFieldValue = ""
    @State private var newCustomFieldIsConceablable = false
    @State private var showingAddCustomField = false
    @State private var editingCustomFieldIndex: Int? = nil
    @State private var editingOriginalCustomFieldKey: String? = nil
    @State private var showingTagEditor = false
    
    @FocusState private var focusedField: CreditCardFocusField?
    
    init(viewModel: CreditCardEditorViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                
                Section {
                    CreditCardSection(
                        viewModel: viewModel,
                        isEditing: viewModel.isEditing,
                        focusedField: $focusedField,
                        onCopy: { value, message in
                            copyToClipboard(value: value, message: message)
                        }
                    )
                } header: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Details")
                    }
                }
                
                
                Section {
                    CreditCardAdditionalDetailsSection(
                        viewModel: viewModel,
                        isEditing: viewModel.isEditing,
                        focusedField: $focusedField,
                        onCopy: { value, message in
                            copyToClipboard(value: value, message: message)
                        }
                    )
                } header: {
                    Text("Additional Details")
                }
                
                if viewModel.isEditing && !viewModel.isLoading {
                    Section {
                        addAnotherFieldComponent()
                    }
                }
                
                
                if !viewModel.creditCardData.customFields.isEmpty {
                    Section("Custom Fields") {
                        ForEach(viewModel.creditCardData.customFields.indices, id: \.self) { index in
                            customFieldRow(index: index)
                        }
                    }
                }
                
                
                Section("Tags") {
                    Button {
                        showingTagEditor = true
                    } label: {
                        tagsRow()
                    }
                    .disabled(!viewModel.isEditing)
                    .buttonStyle(PlainButtonStyle())
                }
                
                
                Section("Notes") {
                    if viewModel.isEditing {
                        MultilineTextField(
                            text: $viewModel.creditCardData.notes,
                            placeholder: "Enter your notes here…",
                            minHeight: 120
                        )
                        .disabled(!viewModel.isEditing)
                        .onChange(of: viewModel.creditCardData.notes) { _ in
                            viewModel.markAsChanged()
                        }
                    } else {
                        Button {
                            copyToClipboard(value: viewModel.creditCardData.notes, message: "Notes Copied")
                        } label: {
                            HStack {
                                Text(viewModel.creditCardData.notes.isEmpty ? "No notes" : viewModel.creditCardData.notes)
                                    .foregroundColor(viewModel.creditCardData.notes.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                
                if !viewModel.isEditing && !viewModel.creditCardData.metadataEntries.isEmpty {
                    Section {
                        DisclosureGroup("Metadata") {
                            ForEach(viewModel.creditCardData.metadataEntries.indices, id: \.self) { index in
                                let entry = viewModel.creditCardData.metadataEntries[index]
                                if entry.copyable {
                                    Button {
                                        copyToClipboard(value: entry.value, message: "'\(entry.key)' Copied")
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.key)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(entry.value)
                                                    .foregroundColor(.primary)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.key)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(entry.value)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.primary)
                        Text(viewModel.navigationTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if shouldShowBackButton {
                        Button(viewModel.cancelButtonTitle) {
                            viewModel.handleCancelTapped()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.handleEditToggle()
                    } label: {
                        if viewModel.isEditing {
                            Image(systemName: "checkmark")
                        } else {
                            Text("Edit")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .modify { view in
                        if #available(iOS 26, *) {
                            view.buttonStyle(.glassProminent)
                        } else {
                            view.buttonStyle(.plain)
                        }
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $viewModel.showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    viewModel.discardChanges()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.dismissDiscardAlert()
                }
            } message: {
                Text("Are you sure you want to discard all your changes?")
            }
            .alert("Error", isPresented: $viewModel.showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onChange(of: viewModel.isEditing) { isEditingNow in
            if isEditingNow {
                focusedField = viewModel.focusFirstField()
            }
        }
        .sheet(isPresented: $showingTagEditor, content: {
            TagsEditorView(currentItemTags: viewModel.creditCardData.tags, allTags: viewModel.model?.tagSet ?? Set()) { cancelled, selectedTags in
                showingTagEditor = false
                if !cancelled {
                    viewModel.onTagsEdited(tags: selectedTags ?? Set())
                }
            }
        })
        .sheet(isPresented: $showingAddCustomField, onDismiss: resetCustomFieldFormState) {
            AddCustomFieldView(
                key: $newCustomFieldKey,
                value: $newCustomFieldValue,
                isConceablable: $newCustomFieldIsConceablable,
                isEditing: editingCustomFieldIndex != nil,
                onSave: { isConceablable in
                    guard !newCustomFieldKey.isEmpty else { return }
                    
                    if let editingIndex = editingCustomFieldIndex {
                        viewModel.updateCustomField(
                            at: editingIndex,
                            key: newCustomFieldKey,
                            value: newCustomFieldValue,
                            isConceablable: isConceablable,
                            originalKey: editingOriginalCustomFieldKey
                        )
                    } else {
                        viewModel.addCustomField(
                            key: newCustomFieldKey,
                            value: newCustomFieldValue,
                            isConceablable: isConceablable
                        )
                    }
                    
                    showingAddCustomField = false
                },
                onCancel: {
                    showingAddCustomField = false
                }
            )
        }
    }
    
    
    private func copyToClipboard(value: String, message: String) {
        guard !value.isEmpty else { return }
        
        
        ClipboardManager.sharedInstance().copyString(withDefaultExpiration: value)
        
        
        CreditCardToastMessages.showSlim(title: message)
    }
}

private extension CreditCardEditorView {
    var shouldShowBackButton: Bool {
#if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .pad
#else
        return true
#endif
    }

    @ViewBuilder
    func addAnotherFieldComponent() -> some View {
        Button {
            presentCustomFieldSheet(for: nil)
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                Text("Add Another Field")
                    .foregroundColor(.primary)
            }
        }
    }
    
    func presentCustomFieldSheet(for index: Int?) {
        if let index = index,
           index < viewModel.creditCardData.customFields.count {
            editingCustomFieldIndex = index
            let existingKey = viewModel.creditCardData.customFields[index]["key"] ?? ""
            editingOriginalCustomFieldKey = existingKey.isEmpty ? nil : existingKey
            newCustomFieldKey = existingKey
            newCustomFieldValue = viewModel.creditCardData.customFields[index]["value"] ?? ""
            newCustomFieldIsConceablable = viewModel.isCustomFieldConceablable(at: index)
        } else {
            resetCustomFieldFormState()
        }
        
        showingAddCustomField = true
    }
    
    func resetCustomFieldFormState() {
        newCustomFieldKey = ""
        newCustomFieldValue = ""
        newCustomFieldIsConceablable = false
        editingCustomFieldIndex = nil
        editingOriginalCustomFieldKey = nil
    }
    
    @ViewBuilder
    func customFieldRow(index: Int) -> some View {
        let fieldKey = viewModel.creditCardData.customFields[index]["key"] ?? ""
        let fieldValue = viewModel.creditCardData.customFields[index]["value"] ?? ""
        let isConcealed = index < viewModel.creditCardData.customFieldsConcealed.count ? viewModel.creditCardData.customFieldsConcealed[index] : false
        let isConceablable = viewModel.isCustomFieldConceablable(at: index)
        
        CreditCardFormRow(icon: nil, title: fieldKey, interactable: false) {
            CreditCardFormSecureInputView("", text: .constant(fieldValue), isSecured: $viewModel.creditCardData.customFieldsConcealed[index])
        } trailingContent: {
            if viewModel.isEditing {
                HStack(spacing: 16) {
                    Button {
                        presentCustomFieldSheet(for: index)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Edit")
                    
                    Button {
                        viewModel.removeCustomField(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Delete")
                }
            } else if isConceablable {
                Button {
                    viewModel.toggleCustomFieldConcealed(at: index)
                } label: {
                    Image(systemName: isConcealed ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .tappable(isTappable: !viewModel.isEditing) {
            copyToClipboard(value: fieldValue, message: "'\(fieldKey)' Copied")
        }
    }
    
    @ViewBuilder
    func tagsRow() -> some View {
        if viewModel.creditCardData.tags.isEmpty {
            HStack {
                Group {
                    Image(.customTagFillBadgePlus)
                        .foregroundStyle(.green, .blue)

                    Text("item_details_tap_to_add_tags")
                }
                .padding(.vertical, 4)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        } else {
            let vm = TagsViewModel(tags: Array(viewModel.creditCardData.tags))
            TagsView(viewModel: vm, useEasyReadFont: true)
        }
    }
}
