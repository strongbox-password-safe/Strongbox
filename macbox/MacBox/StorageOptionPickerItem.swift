//
//  StorageOptionPickerItem.swift
//  MacBox
//
//  Created by Strongbox on 08/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct StorageOptionPickerItem: View {
    @Binding var selection: StorageOption?
    var option: StorageOption
    var disabled: Bool = false
    var disabledReason: String?
    var createMode: Bool

    var body: some View {
        Button {
            selection = option
        } label: {
            Label(selection: $selection, option: option, disabled: disabled, disabledReason: disabledReason, createMode: createMode)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!disabled)

    }
}

private struct Label: View {
    @Binding var selection: StorageOption?
    var option: StorageOption
    @State private var isHovering = false
    var disabled: Bool = false
    var disabledReason: String?
    var createMode: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let backgroundFillStyle = selection == option ?
            AnyShapeStyle(Color.accentColor) :
            AnyShapeStyle(colorScheme == .dark ? Color.black : .white)

        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                let img = Image(nsImage: option.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.accentColor)

                ZStack {
                    Rectangle()
                        .cornerRadius(15)
                        .shadow(radius: 3)
                        .foregroundColor(Color(white: 0.92))
                        .border(.clear)
                        .frame(width: 40, height: 40)

                    if disabled {
                        img.saturation(0.0)
                    } else {
                        img
                    }
                }

                VStack(alignment: .leading) {
                    Text(option.name)
                        .font(.body)
                        .bold()
                        .foregroundStyle(disabled ? shapeStyle(Color.secondary) : shapeStyle(Color.primary))

                    if let disabledReason, disabled {
                        Text(disabledReason)
                            .fixedSize(horizontal: false, vertical: true)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(shapeStyle(Color.orange))
                    } else {
                        if option.description(createMode).count > 0 {
                            Text(option.description(createMode))
                                .fixedSize(horizontal: false, vertical: true)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(shapeStyle(Color.secondary))
                        }
                    }
                }

                Spacer()
            }
        }
        .frame(width: 250)
        .shadow(radius: selection == option ? 4 : 0)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFillStyle)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovering ? (disabled ? Color.gray : Color.accentColor) : .clear)
        }
        .scaleEffect(isHovering && !disabled ? 1.02 : 1)
        .onHover { isHovering in
            withAnimation {
                self.isHovering = isHovering
            }
        }
    }

    func shapeStyle(_ style: some ShapeStyle) -> some ShapeStyle {
        if selection == option {
            return AnyShapeStyle(.white)
        } else {
            return AnyShapeStyle(style)
        }
    }
}

#Preview {
    let wo = StorageOption.wifiSync(server: WiFiSyncServerConfig(name: "No Devices Found"))

    return VStack {
        StorageOptionPickerItem(selection: .constant(nil), option: wo, disabled: true, createMode: false)
        

        StorageOptionPickerItem(selection: .constant(nil), option: .cloudKit, disabled: true,
                                disabledReason: "This is disabled because blah blah", createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .cloudKit, createMode: false)
        StorageOptionPickerItem(selection: .constant(.cloudKit), option: .cloudKit, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .localDevice, createMode: false)
        StorageOptionPickerItem(selection: .constant(.localDevice), option: .localDevice, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .dropbox, createMode: false)
        StorageOptionPickerItem(selection: .constant(.dropbox), option: .dropbox, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .googledrive, createMode: false)
        StorageOptionPickerItem(selection: .constant(.googledrive), option: .googledrive, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .onedrive, createMode: false)
        StorageOptionPickerItem(selection: .constant(.onedrive), option: .onedrive, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .sftp, createMode: false)
        StorageOptionPickerItem(selection: .constant(.sftp), option: .sftp, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .webdav, createMode: false)
        StorageOptionPickerItem(selection: .constant(.webdav), option: .webdav, createMode: false)

        StorageOptionPickerItem(selection: .constant(nil), option: .wifiSync(server: WiFiSyncServerConfig(name: "My WiFi Sync Device")), createMode: false)

        let foo = StorageOption.wifiSync(server: WiFiSyncServerConfig(name: "My WiFi Sync Device"))
        StorageOptionPickerItem(selection: .constant(foo), option: foo, createMode: false)



    }.padding()
}
