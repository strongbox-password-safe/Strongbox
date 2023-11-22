//
//  PasskeyWizardChooseCreateOrAdd.swift
//  TestSwiftUINav
//
//  Created by Strongbox on 15/09/2023.
//

import SwiftUI

#if os(iOS)
    @available(iOS 17.0, *)
    struct PasskeyWizardChooseCreateOrAdd: View {
        @Environment(\.dismiss) private var dismiss

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            VStack {
                VStack {
                    Image("AppIcon-2019-1024")
                        .resizable()
                        .frame(width: 40, height: 40)

                    Text("passkey_new_passkey_title").font(.title)

                    Text("passkey_how_to_add_to_database")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                }

                VStack(spacing: 20) {
                    NavigationLink("passkey_add_by_creating_new", value: "create")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .cornerRadius(5)

                    NavigationLink("passkey_add_to_existing", value: "add")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .cornerRadius(5)

                    Button {
                        dismiss()
                        completion?(true, false, nil, nil, nil)
                    } label: {
                        Text("generic_cancel")
                    }
                }
                .padding(20)
            }
            .padding()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
#else

    @available(macOS 14.0, *)
    struct PasskeyWizardChooseCreateOrAdd: View {
        @Environment(\.dismiss) private var dismiss

        var completion: ((_ cancel: Bool, _ createNew: Bool, _ title: String?, _ selectedGroupIdx: Int?, _ selectedEntry: UUID?) -> Void)?

        var body: some View {
            Spacer()

            VStack(spacing: 20) {
                VStack {
                    Image("StrongBox-256x256")
                        .resizable()
                        .frame(width: 40, height: 40)

                    Text("passkey_new_passkey_title").font(.title)

                    Text("passkey_how_to_add_to_database")
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.subheadline)
                }

                VStack(spacing: 16) {
                    NavigationLink(value: "create") {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("passkey_add_by_creating_new")
                        }
                        .frame(width: 250)
                        .frame(height: 35)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .buttonStyle(.borderedProminent)

                    NavigationLink(value: "add") {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.fill.badge.plus")
                                .font(.system(size: 16))
                            Text("passkey_add_to_existing")
                        }
                        .frame(width: 250)
                        .frame(height: 35)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    dismiss()
                    completion?(true, false, nil, nil, nil)
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .frame(maxWidth: 400)

            Spacer()
        }
    }
#endif
