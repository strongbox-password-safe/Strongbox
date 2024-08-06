//
//  EntryViewContextMenu.swift
//  Strongbox
//
//  Created by Strongbox on 29/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct ShowLargePasswordButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface

    var body: some View {
        Button(action: {
            model.showPassword(entry: entry)
        }) {
            HStack {
                Text("browse_context_menu_show_password")
                Image(systemName: "eye")
            }
        }
    }
}

struct GenericCopyButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface
    var title: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Image(systemName: "doc.on.doc")
            }
        }
    }
}

































struct CopyAndLaunchButton: View {
    var model: DatabaseHomeViewModel
    var entry: any SwiftEntryModelInterface

    var body: some View {
        Button(action: {
            model.copyAndLaunch(entry: entry)
        }) {
            HStack {
                Text("browse_action_launch_url_copy_password")
                Image(systemName: "bolt")
            }
        }
    }
}
















struct DeleteOrRecycleItemButton: View {
    var model: DatabaseHomeViewModel
    var item: any SwiftItemModelInterface
    var recycle: Bool

    var body: some View {
        Button(role: .destructive, action: {
            Task {
                await model.deleteItem(item: item)
            }
        }) {
            HStack {
                Text(recycle ? "generic_action_verb_recycle" : "browse_vc_action_delete")
                Image(systemName: "trash")
            }
        }
    }
}

struct EntryViewContextMenu: View {
    var model: DatabaseHomeViewModel
    var item: any SwiftItemModelInterface
    var database: SwiftDatabaseModelInterface { model.database }

    var body: some View {
        VStack {
            let isRecycleBin = item.isGroup && database.isKeePass2Format && database.recycleBinNodeUuid == item.uuid

            if !database.isReadOnly, isRecycleBin {
                EmptyRecycleBinButton(model: model)
            }

            if !database.isReadOnly, !item.isGroup, let entry = item as? any SwiftEntryModelInterface {
                ToggleFavouriteButton(model: model, entry: entry)
            }

            if !item.isGroup, let entry = item as? any SwiftEntryModelInterface {
                if !entry.password.isEmpty {
                    GenericCopyButton(model: model, entry: entry, title: "browse_prefs_tap_action_copy_copy_password") {
                        model.copyPassword(entry: entry)
                    }

                    ShowLargePasswordButton(model: model, entry: entry)
                }

                if entry.isFlaggedByAudit {
                    ShowAuditDrilldownButton(model: model, entry: entry)
                }
            }

            
            
            
            
            
            

            if item.isGroup {
                
            }

            Divider()

            Menu("browse_context_menu_copy_other_field") {
                if !item.isGroup, let entry = item as? any SwiftEntryModelInterface {
                    GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_all_fields") {
                        model.copyAllFields(entry: entry)
                    }

                    if !entry.username.isEmpty {
                        GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_username") {
                            model.copyUsername(entry: entry)
                        }
                    }

                    if entry.totp != nil {
                        GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_totp") {
                            model.copyTotp(entry: entry)
                        }
                    }

                    if !entry.url.isEmpty {
                        GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_url") {
                            model.copyUrl(entry: entry)
                        }
                    }

                    if !entry.email.isEmpty {
                        GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_email") {
                            model.copyEmail(entry: entry)
                        }
                    }

                    if !entry.notes.isEmpty {
                        GenericCopyButton(model: model, entry: entry, title: "generic_fieldname_notes") {
                            model.copyNotes(entry: entry)
                        }
                    }

                    if entry.launchableUrl != nil {
                        CopyAndLaunchButton(model: model, entry: entry)
                    }

                    

                    Divider()

                    ForEach(entry.customFields.keys, id: \.self) { key in
                        if let value = entry.customFields[key], !value.value.isEmpty {
                            GenericCopyButton(model: model, entry: entry, title: .init(key)) {
                                model.copyCustomField(key: key, entry: entry)
                            }
                        }
                    }
                }
            }

            Divider()

            if !item.isGroup, let entry = item as? any SwiftEntryModelInterface, !self.model.database.isReadOnly {
                

                
                
            } else {
                

                

                
                
                
                
            }

            





            

            
            
            
            
            

            if !model.database.isReadOnly, !isRecycleBin || database.recycleBinCount == 0 {
                DeleteOrRecycleItemButton(model: model, item: item, recycle: model.canRecycle(item: item))
            }
        }
    }
}

#Preview {
    Image(systemName: "doc")
        .contextMenu {
            EntryViewContextMenu(model: DatabaseHomeViewModel(), item: SwiftDummyEntryModel())
        }
}
