//
//  CreateVirtualHardwareKeyView.swift
//  MacBox
//
//  Created by Strongbox on 10/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct CreateVirtualHardwareKeyView: View {
    var completion: ((_ userCancelled: Bool, _ name: String, _ secret: String, _ fixedLength: Bool) -> Void)?

    @State var name: String = ""
    @State var secret: String = ""
    @State var fixedLength: Bool = false

    var isValid: Bool {
        !name.isEmpty && !secret.isEmpty && secret.isHexString
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                HStack {
                    Image(.yubikey)
                        .resizable()
                        .foregroundColor(.blue)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 45, height: 45)
                        .rotationEffect(.degrees(180))

                    Text("new_virtual_hardware_key")
                        .font(.largeTitle)
                        .bold()
                }

                Text("virtual_hardware_key_welcome_msg")
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField("generic_name", text: $name, prompt: Text("sample_vkey_name_my_backup_key"))
                TextField("vkey_secret", text: $secret, prompt: Text("32b720b6adeadbeefa9add92438083a9abee660d"))

                Toggle("Fixed Length Input", isOn: $fixedLength)
                    .controlSize(.regular)
                Text("vkey_secret_description")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.large)
            .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    completion?(true, name, secret, fixedLength)
                } label: {
                    Text("generic_cancel")
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    completion?(false, name, secret, fixedLength)
                } label: {
                    Text("casg_add_action")
                }
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .frame(width: 400)
        .scenePadding()
    }
}

#Preview {
    CreateVirtualHardwareKeyView()
}
