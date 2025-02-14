//
//  SettingsNavBarButton.swift
//  Strongbox
//
//  Created by Strongbox on 01/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct SettingsNavBarButton: View {
    @ObservedObject
    var model: DatabaseHomeViewModel

    var biometricsIdName: String {
        model.biometricsIsFaceId ? NSLocalizedString("settings_face_id_name", comment: "Face ID") : NSLocalizedString("settings_touch_id_name", comment: "Touch ID")
    }

    var body: some View {
        Menu {
            Toggle(isOn: $model.startWithSearch, label: {
                HStack {
                    Text("browse_context_menu_start_with_search")
                    Image(systemName: "magnifyingglass")
                }
            })

            Divider()

            Menu("configure_home_show_sections", systemImage: "slider.horizontal.3") {
                ForEach(HomeViewSection.allCases) { section in
                    Toggle(isOn: Binding(
                        get: {
                            model.isHomeViewSectionVisible(section: section)
                        },
                        set: { newValue in
                            model.setHomeViewSectionVisible(section: section, visible: newValue)
                        }
                    ),
                    label: {
                        HStack {
                            Text(section.title)
                            Image(systemName: section.imageName)
                        }
                    })
                }
            }

            Button(action: {
                model.presentConfigureTabsView()
            }, label: {
                HStack {
                    Text("configure_tabs")
                    Image(systemName: "list.bullet.below.rectangle")
                }
            })

            Divider()

            Button(action: {
                model.presentConvenienceUnlockPreferences()
            }, label: {
                HStack {
                    let title = String(format: NSLocalizedString("convenience_unlock_preferences_title_fmt", comment: "%@ & PIN Codes"), biometricsIdName)

                    Text(title)
                    Image(systemName: model.biometricsIsFaceId ? "faceid" : "touchid")
                }
            })

            Button(action: {
                model.presentAutoFillSettings()
            }, label: {
                HStack {
                    Text("generic_autofill_settings")
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                }
            })
            Button(action: {
                model.presentAuditSettings()
            }, label: {
                HStack {
                    Text("browse_vc_action_audit")
                    Image(systemName: "checkmark.shield")
                }
            })
            Button(action: {
                model.presentAutoLockSettings()
            }, label: {
                HStack {
                    Text("generic_auto_lock_settings")
                    Image(systemName: "lock.rotation.open")
                }
            })
            Button(action: {
                model.presentEncryptionSettings()
            }, label: {
                HStack {
                    Text("generic_encryption_settings")
                    Image(systemName: "function")
                }
            })

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

            if model.shouldShowYubiKeySettingsOption {
                Button(action: {
                    model.presentHardwareKeySettings()
                }, label: {
                    HStack {
                        Text("generic_hardware_key")
                        Image(.yubikey)
                    }
                })
            }

            Button(action: {
                model.presentAdvancedSettings()
            }, label: {
                HStack {
                    Text("generic_advanced_noun")
                    Image(systemName: "gear")
                }
            })
        } label: {
            Image(systemName: "gear")
        }
    }
}

#Preview {
    NavigationView {
        Text("Test")
            .navigationTitle("Testing")
            .navigationBarItems(leading: SettingsNavBarButton(model: DatabaseHomeViewModel()))
    }
}
