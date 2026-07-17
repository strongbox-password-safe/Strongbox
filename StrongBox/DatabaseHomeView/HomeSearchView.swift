//
//  HomeSearchView.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI
import UIKit

enum HomeSearchSelectionActions {
    static func canMerge(selectedItemsContainCreditCard: [Bool]) -> Bool {
        selectedItemsContainCreditCard.count == 2 && !selectedItemsContainCreditCard.contains(true)
    }

    static func canMoveOrDelete(selectedItemCount: Int, isReadOnly: Bool) -> Bool {
        selectedItemCount > 0 && !isReadOnly
    }

    static func canExport(selectedItemCount: Int, isExportAvailable: Bool) -> Bool {
        selectedItemCount > 0 && isExportAvailable
    }
}

struct HomeSearchView: View {
    private struct SearchResultWrapperFFS: Identifiable {
        var id: UUID { result.uuid }
        var result: any SwiftEntryModelInterface
    }

    @AppStorage(
        "search_allow_expired",
        store: AppPreferences.sharedInstance().sharedAppGroupDefaults
    ) var allowExpired: Bool = false

    @ObservedObject
    var model: DatabaseHomeViewModel

    @Binding
    var searchText: String
    @Binding
    var searchScope: SearchScope

    private var searchResults: [SearchResultWrapperFFS] {
        let matches = model.search(searchText: searchText, searchScope: searchScope, allowExpired: allowExpired)

        return matches.map { SearchResultWrapperFFS(result: $0) }
    }

    @State
    var selection: Set<UUID> = .init()

    @State
    var isSelecting: Bool = false

    private var selectedEntries: [any SwiftEntryModelInterface] {
        searchResults.compactMap { wrapper in
            selection.contains(wrapper.result.uuid) ? wrapper.result : nil
        }
    }

    private var canMergeSelectedEntries: Bool {
        HomeSearchSelectionActions.canMerge(selectedItemsContainCreditCard: selectedEntries.map(\.isCreditCard))
    }

    private var canMoveOrDeleteSelectedEntries: Bool {
        HomeSearchSelectionActions.canMoveOrDelete(selectedItemCount: selectedEntries.count, isReadOnly: model.database.isReadOnly)
    }

    private var canExportSelectedEntries: Bool {
        HomeSearchSelectionActions.canExport(selectedItemCount: selectedEntries.count, isExportAvailable: model.canExportItems)
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if isSelecting {
                        searchSelectionToolbar
                    }

                    showExpiredBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button("generic_done") {
                            selection.removeAll()
                            isSelecting = false
                        }
                        .disabled(searchResults.isEmpty)
                        .opacity(searchResults.isEmpty ? 0 : 1)
                    } else {
                        Button("generic_select_items") {
                            isSelecting = true
                        }
                        .disabled(searchResults.isEmpty)
                        .opacity(searchResults.isEmpty ? 0 : 1)
                    }
                }
            }
            .animation(.snappy, value: searchResults.count)
    }

    var content: some View {
        Group {
            if #available(iOS 17.0, *) {
                if searchResults.isEmpty, !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    list
                }
            } else {
                list
            }
        }
    }

    var showExpiredBar: some View {
        HStack {
            Spacer()

            Toggle(isOn: $allowExpired, label: {
                Text("search_show_expired")
            })
            .font(.subheadline.weight(.regular))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Material.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    var searchSelectionToolbar: some View {
        HomeSearchSelectionToolbar(
            canMoveOrDelete: canMoveOrDeleteSelectedEntries,
            canExport: canExportSelectedEntries,
            canMerge: canMergeSelectedEntries,
            onMove: {
                Task {
                    await moveSelectedEntries()
                }
            },
            onExport: {
                Task {
                    await exportSelectedEntries()
                }
            },
            onMerge: {
                Task {
                    await mergeSelectedEntries()
                }
            },
            onDelete: {
                Task {
                    await deleteSelectedEntries()
                }
            }
        )
        .frame(height: 44)
    }

    var list: some View {
        List(searchResults, selection: $selection) { wrapper in
            Button(action: {
                model.navigateTo(destination: .entryDetail(uuid: wrapper.result.uuid, search: true))
            }, label: {
                SwiftUIEntryView(entry: wrapper.result, showIcon: model.showIcons, easyReadSeparator: model.twoFactorShowSeparator)
                    .contextMenu {
                        EntryViewContextMenu(model: model, item: wrapper.result)
                        Divider()
                        Button {
                            selection = [wrapper.result.uuid]
                            isSelecting = true
                        } label: {
                            Label("generic_select_items", systemImage: "checkmark.circle")
                        }
                        Button {
                            selection = Set(searchResults.map(\.result.uuid))
                            isSelecting = true
                        } label: {
                            Label("generic_select_all", systemImage: "checkmark.circle.fill")
                        }
                    }
            })
        }
        .transition(.opacity)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
    }

    @MainActor
    private func moveSelectedEntries() async {
        guard canMoveOrDeleteSelectedEntries else { return }

        let moved = await model.moveItems(items: selectedEntries)
        if moved {
            selection.removeAll()
            isSelecting = false
        }
    }

    @MainActor
    private func exportSelectedEntries() async {
        guard canExportSelectedEntries else { return }

        let exported = await model.exportItems(items: selectedEntries)
        if exported {
            selection.removeAll()
            isSelecting = false
        }
    }

    @MainActor
    private func mergeSelectedEntries() async {
        guard canMergeSelectedEntries, selectedEntries.count == 2 else { return }

        let merged = await model.merge(entryA: selectedEntries[0], entryB: selectedEntries[1])
        if merged {
            selection.removeAll()
            isSelecting = false
            model.objectWillChange.send()
        }
    }

    @MainActor
    private func deleteSelectedEntries() async {
        guard !selectedEntries.isEmpty, !model.database.isReadOnly else { return }

        let deleted = await model.deleteItems(items: selectedEntries)
        if deleted {
            selection.removeAll()
            isSelecting = false
            model.objectWillChange.send()
        }
    }
}

private struct HomeSearchSelectionToolbar: UIViewRepresentable {
    var canMoveOrDelete: Bool
    var canExport: Bool
    var canMerge: Bool
    var onMove: () -> Void
    var onExport: () -> Void
    var onMerge: () -> Void
    var onDelete: () -> Void

    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.isTranslucent = true
        toolbar.setItems(context.coordinator.items, animated: false)
        return toolbar
    }

    func updateUIView(_ toolbar: UIToolbar, context: Context) {
        context.coordinator.onMove = onMove
        context.coordinator.onExport = onExport
        context.coordinator.onMerge = onMerge
        context.coordinator.onDelete = onDelete

        context.coordinator.update(
            canMoveOrDelete: canMoveOrDelete,
            canExport: canExport,
            canMerge: canMerge
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var onMove: () -> Void = {}
        var onExport: () -> Void = {}
        var onMerge: () -> Void = {}
        var onDelete: () -> Void = {}

        let moveButton: UIBarButtonItem
        let exportButton: UIBarButtonItem
        let mergeButton: UIBarButtonItem
        let deleteButton: UIBarButtonItem
        let items: [UIBarButtonItem]

        override init() {
            moveButton = UIBarButtonItem(
                title: NSLocalizedString("generic_move_ellipsis", comment: "Move..."),
                style: .plain,
                target: nil,
                action: nil
            )
            exportButton = UIBarButtonItem(
                title: NSLocalizedString("generic_export_ellipsis", comment: "Export..."),
                style: .plain,
                target: nil,
                action: nil
            )
            mergeButton = UIBarButtonItem(
                title: NSLocalizedString("generic_action_merge", comment: "Merge"),
                style: .plain,
                target: nil,
                action: nil
            )
            deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: nil, action: nil)
            deleteButton.tintColor = .systemRed
            deleteButton.accessibilityLabel = NSLocalizedString("browse_vc_action_delete", comment: "Delete")
            items = [
                UIBarButtonItem(systemItem: .flexibleSpace),
                moveButton,
                UIBarButtonItem(systemItem: .flexibleSpace),
                exportButton,
                UIBarButtonItem(systemItem: .flexibleSpace),
                mergeButton,
                UIBarButtonItem(systemItem: .flexibleSpace),
                deleteButton,
                UIBarButtonItem(systemItem: .flexibleSpace)
            ]

            super.init()

            moveButton.target = self
            moveButton.action = #selector(move)
            exportButton.target = self
            exportButton.action = #selector(export)
            mergeButton.target = self
            mergeButton.action = #selector(merge)
            deleteButton.target = self
            deleteButton.action = #selector(delete)
        }

        func update(canMoveOrDelete: Bool, canExport: Bool, canMerge: Bool) {
            moveButton.isEnabled = canMoveOrDelete
            exportButton.isEnabled = canExport
            mergeButton.isEnabled = canMerge
            deleteButton.isEnabled = canMoveOrDelete
        }

        @objc func move() {
            onMove()
        }

        @objc func export() {
            onExport()
        }

        @objc func merge() {
            onMerge()
        }

        @objc func delete() {
            onDelete()
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @State
    var searchText: String = ""
    @Previewable @State
    var searchScope: SearchScope = .all

    let model = DatabaseHomeViewModel()

    return NavigationStack {
        HomeSearchView(model: model, searchText: $searchText, searchScope: $searchScope)

            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "generic_verb_search")
            .navigationTitle(model.database.nickName)
            .navigationBarTitleDisplayMode(.large)
    }
}
