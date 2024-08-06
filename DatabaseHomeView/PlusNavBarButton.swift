//
//  PlusNavBarButton.swift
//  Strongbox
//
//  Created by Strongbox on 01/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct PlusNavBarButton: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    var body: some View {
        Menu {
            Button(action: {
                model.onAddEntry()
            }, label: {
                HStack {
                    Text("browse_context_menu_new_entry")
                    Image(systemName: "doc.badge.plus")
                }
            })
            .disabled(model.database.isReadOnly)

            Divider()

            Button(action: {
                model.presentSetMasterCredentials()
            }, label: {
                HStack {
                    Text("browse_context_menu_set_master_credentials")
                    Image(systemName: "ellipsis.rectangle")
                }
            })
            .disabled(model.database.isReadOnly)

            Divider()

            if !model.disableExport {
                Button(action: {
                    model.exportDatabase()
                }, label: {
                    HStack {
                        Text("generic_export_database")
                        Image(systemName: "square.and.arrow.up")
                    }
                })
            }

            if !model.disablePrinting {
                Button(action: {
                    model.printDatabase()
                }, label: {
                    HStack {
                        Text("generic_print_database")
                        Image(systemName: "printer")
                    }
                })
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

#Preview {
    NavigationView {
        Text("Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PlusNavBarButton(model: DatabaseHomeViewModel())
                }
            }
            .navigationTitle("Testing")
    }
}
