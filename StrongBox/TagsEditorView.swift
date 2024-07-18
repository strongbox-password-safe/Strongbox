//
//  TagsEditorView.swift
//  Strongbox
//
//  Created by Strongbox on 08/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct TagsEditorView: View {
    var currentItemTags: Set<String>
    var allTags: Set<String>
    var completion: (_ cancelled: Bool, _ selectedTags: Set<String>?) -> Void

    @State var searchText: String = ""
    @State var isSearchPresented = true

    var body: some View {
        NavigationView {
            let foo = TagsList(currentItemTags: currentItemTags, allTags: allTags, searchText: searchText, completion: completion)

            if #available(iOS 17.0, *) {
                foo.searchable(text: $searchText, isPresented: $isSearchPresented, placement: .navigationBarDrawer, prompt: allTags.isEmpty ? "tags_editor_create_new_tag_ellipsis" : "tags_editor_search_or_create_ellipsis")
            } else {
                foo.searchable(text: $searchText, placement: .navigationBarDrawer, prompt: allTags.isEmpty ? "tags_editor_create_new_tag_ellipsis" : "tags_editor_search_or_create_ellipsis")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct TagsList: View {
    @State private var dummySelection = Set<String>()
    @State var currentItemTags: Set<String>
    @State var allTags: Set<String>

    private let originalItemTags: Set<String>

    init(currentItemTags: Set<String>,
         allTags: Set<String>,
         searchText: String,
         completion: @escaping (_: Bool, _: Set<String>?) -> Void)
    {
        self.currentItemTags = currentItemTags
        originalItemTags = currentItemTags

        

        self.searchText = searchText
        self.completion = completion

        var tmp = allTags
        tmp.remove(kCanonicalFavouriteTag)
        self.allTags = tmp
    }

    var searchText: String

    var completion: (_ cancelled: Bool, _ selectedTags: Set<String>?) -> Void

    @Environment(\.dismissSearch) private var dismissSearch

    var trimmedSearchText: String {
        trim(searchText)
    }

    var available: [String] {
        let sortedAllTags = Array(allTags).sorted { tag1, tag2 in
            finderStringCompare(tag1, tag2) == .orderedAscending
        }

        let avail = sortedAllTags.filter { tag in
            !currentItemTags.contains(tag)
        }

        guard searchText.count > 0 else {
            return avail
        }

        return avail.filter { theTag in
            theTag.localizedCaseInsensitiveContains(searchText)
        }
    }

    var current: [String] {
        let sortedCurrentItemTags = Array(currentItemTags).sorted { tag1, tag2 in
            finderStringCompare(tag1, tag2) == .orderedAscending
        }

        guard searchText.count > 0 else {
            return sortedCurrentItemTags
        }

        return sortedCurrentItemTags.filter { theTag in
            theTag.localizedCaseInsensitiveContains(searchText)
        }
    }

    var isEmptyNoTagsToDisplay: Bool {
        available.isEmpty && current.isEmpty
    }

    func removeTag(tag: String) {
        dummySelection.removeAll()
        currentItemTags.remove(tag)
        dismissSearch()
    }

    func addTagToCurrentItemTags(tag: String) {
        dummySelection.removeAll()

        let trimmed = trim(tag)

        guard trimmed.count > 0, tag != kCanonicalFavouriteTag else {
            return
        }

        allTags.insert(trimmed)
        currentItemTags.insert(trimmed)
        dismissSearch()
    }

    func createNewTag(tag: String) {
        addTagToCurrentItemTags(tag: tag)
    }

    func bluePlusCircle() -> some View {
        Image(systemName: "plus")
            .resizable()
            .frame(width: 12, height: 12)
            .font(.headline)
            .padding(6)
            .background(Color.blue)
            .clipShape(Circle())
            .foregroundColor(.white)
    }

    func redMinusCircle() -> some View {
        Image(systemName: "minus.circle.fill")
            .resizable()
            .frame(width: 21, height: 21)
            .font(.headline)
            .background(Color.white)
            .clipShape(Circle())
            .foregroundColor(.red)
    }

    func createNewTagButton() -> some View {
        Button(action: {
            createNewTag(tag: trimmedSearchText)
        }, label: {
            HStack {
                bluePlusCircle()

                HStack(spacing: 4) {
                    Text(String(format: NSLocalizedString("tags_editor_create_tag_fmt", comment: "No Results for \"%@\""), searchText)).font(.headline)
                }
            }
        })
    }

    var body: some View {
        List(selection: $dummySelection) {
            if searchText.count > 0, !allTags.contains(trimmedSearchText), !trimmedSearchText.isEmpty {
                createNewTagButton()
            }

            if !current.isEmpty {
                Section(header: Text("tags_editor_header_current_tags")) {
                    ForEach(current, id: \.self) { tag in
                        HStack {
                            HStack {
                                Image(systemName: "tag")
                                    .font(.headline)
                                    .foregroundColor(.blue)

                                Text("\(tag)")
                            }

                            Spacer()

                            Button {
                                
                            } label: {
                                redMinusCircle()
                                    .onTapGesture {
                                        removeTag(tag: tag)
                                    }
                            }
                            .accessibilityLabel(Text("mac_undo_action_remove_tag"))
                        }
                    }
                }
            }

            if available.count > 0 {
                Section(header:
                    Text("tags_editor_create_available_tags")
                ) {
                    ForEach(available, id: \.self) { tag in
                        Button {
                            addTagToCurrentItemTags(tag: tag)
                        } label: {
                            HStack {
                                HStack {
                                    Image(systemName: "tag")
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    Text("\(tag)")
                                }

                                Spacer()

                                bluePlusCircle()
                            }
                        }
                        .accessibilityLabel(Text("mac_undo_action_add_tag"))
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("tags_editor_header_edit_tags")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(leading: Button(action: {
            completion(true, nil)
        }) {
            originalItemTags == currentItemTags ? Text("generic_cancel") : Text("generic_verb_discard")
        }, trailing: Button(action: {
            completion(false, currentItemTags)
        }) {
            Text("mac_save_action").bold()
        }.disabled(originalItemTags == currentItemTags))
        .overlay {
            if allTags.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tag.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    VStack {
                        Text("tags_editor_create_no_tags_yet")
                            .font(.title2)
                            .bold()

                        Text("tags_editor_create_start_typing_to_create")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else if isEmptyNoTagsToDisplay {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    VStack {
                        Text(String(format: NSLocalizedString("tags_editor_no_results_for_fmt", comment: "No Results for \"%@\""), searchText))
                            .font(.title2)
                            .bold()

                        Text("tags_editor_check_spelling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if !allTags.contains(trimmedSearchText), !trimmedSearchText.isEmpty {
                        Button(action: {
                            createNewTag(tag: trimmedSearchText)
                        }, label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.title3)

                                Text(String(format: NSLocalizedString("tags_editor_create_tag_fmt", comment: "Create \"%@\" tag"), searchText))
                                    .font(.headline)
                            }
                        })
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    let allTags = [
        "Alpha - Α α",
        "Beta - Β β",
        "Gamma - Γ γ",
        "Delta - Δ δ",
        "Epsilon - Ε ε",
        "Zeta - Ζ ζ",
        "Eta - Η η",
        "Theta - Θ θ",
        "Iota - Ι ι",
        "Kappa - Κ κ",
        "Lambda - Λ λ",
        "Mu - Μ μ",
        "Nu - Ν ν",
        "Xi - Ξ ξ",
        "Omicron - Ο ο",
        "Pi - Π π",
        "Rho - Ρ ρ",
        "Sigma - Σ σ/ς",
        "Tau - Τ τ",
        "Upsilon - Υ υ",
        "Phi - Φ φ",
        "Chi - Χ χ",
        "Psi - Ψ ψ",
        "Omega - Ω ω",
        "Foo",
        "Bar",
    ]

    let currentItemTags = ["Alpha - Α α", "Gamma - Γ γ", "Iota - Ι ι", "Phi - Φ φ", "Omega - Ω ω", "Tau - Τ τ"]

    return TagsEditorView(currentItemTags: Set(currentItemTags), allTags: Set(allTags)) { cancelled, selectedTags in
        print("completion called with \(cancelled) - \(selectedTags)")
    }
}
