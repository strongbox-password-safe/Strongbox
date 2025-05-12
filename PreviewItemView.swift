import SwiftUI
import UIKit

struct PreviewItemView: View {
    var item: Node
    var model: Model

    
    @State private var currentDate = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                
                HStack(alignment: .center, spacing: 8) {
                    Image(uiImage: NodeIconHelper.getIconFor(
                        item,
                        predefinedIconSet: model.metadata.keePassIconSet,
                        format: model.database.originalFormat
                    ))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                    Text(maybeDereference(item.title))
                        .font(Font(FontManager.shared.title3Font).weight(.semibold))
                }

                
                if let otpToken = item.fields.otpToken {
                    VStack(alignment: .leading, spacing: 2) {
                        if #available(iOS 16.0, *) {
                            TwoFactorView(
                                totp: otpToken,
                                updateMode: .automatic,
                                easyReadSeparator: AppPreferences.sharedInstance().twoFactorEasyReadSeparator,
                                font: .title3,
                                hideCountdownDigits: true,
                                radius: UIFont.preferredFont(forTextStyle: .title3).lineHeight * 1.5,
                                title: nil,
                                subtitle: nil,
                                image: nil,
                                onQrCode: nil)
                        } else {
                            RowHeader(text: "Token")
                            LegacyTwoFactorView(otpToken: otpToken)
                        }
                    }
                }

                
                ForEach(orderedFields, id: \.key) { field in
                    EntryRow(label: field.key, value: field.value)
                }

                Spacer()
            }
            .padding(12)
        }
        .frame(minWidth: 250, alignment: .leading)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .onReceive(timer) { input in
            self.currentDate = input
        }
    }

    

    
    var orderedFields: [(key: String, value: String)] {
        var fields = [(key: String, value: String)]()
        let username = item.fields.username
        if !username.isEmpty {
            fields.append(
                (NSLocalizedString(
                    "generic_fieldname_username",
                    comment: "Username"
                ),
                maybeDereference(username)))
        }
        let email = item.fields.email
        if !email.isEmpty {
            fields.append(
                (NSLocalizedString(
                    "generic_fieldname_email",
                    comment: "Email"
                ),
                maybeDereference(email)))
        }
        let sortedKeys = item.fields.customFieldsNoEmail.keys.sorted { $0.localizedStandardCompare($1 as String) == .orderedAscending }
        for key in sortedKeys {
            if !NodeFields.isTotpCustomFieldKey(key as String) {
                if let sv = item.fields.customFields[key] {
                    let derefed = maybeDereference(sv.value)
                    if !sv.protected && !derefed.isEmpty {
                        fields.append((key as String, derefed))
                    }
                }
            }
        }
        let notes = item.fields.notes
        if !notes.isEmpty {
            fields.append(
                (NSLocalizedString(
                    "generic_fieldname_notes",
                    comment: "Notes"
                ),
                maybeDereference(notes)))
        }
        return fields
    }

    
    func maybeDereference(_ text: String) -> String {
        if model.metadata.viewDereferencedFields {
            return model.database.dereference(text, node: item)
        } else {
            return text
        }
    }
}

private struct EntryRow: View {
    var label: String
    var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            RowHeader(text: label)
            RowBody(text: value)
        }
    }
}

private struct RowHeader: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(Font(FontManager.shared.caption2Font))
            .foregroundColor(.secondary)
    }
}

private struct RowBody: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(Font(FontManager.shared.regularFont))
            .foregroundColor(.primary)
    }
}

private struct LegacyTwoFactorView: View {
    var otpToken: OTPToken

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            let currentDate = timeline.date
            let period = otpToken.period
            let currentTime = currentDate.timeIntervalSince1970
            let remainingSeconds = UInt64(period) - UInt64(currentTime.truncatingRemainder(dividingBy: Double(period)))

            let displayColor: Color = {
                if remainingSeconds < 5 {
                    return .red
                } else if remainingSeconds < 9 {
                    return .orange
                } else {
                    return .primary
                }
            }()

            
            
            let blink: Bool = {
                if remainingSeconds < 16 {
                    
                    return currentDate.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) < 0.45
                } else {
                    return false
                }
            }()

            HStack(alignment: .center, spacing: 6) {
                if let codes = otpToken.codeSeparated,
                   codes.count == 2,
                   AppPreferences.sharedInstance().twoFactorEasyReadSeparator {
                    Text(codes[0])
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(displayColor)
                        
                        .opacity(blink ? 0.5 : 1.0)
                    Text(codes[1])
                        .foregroundColor(.primary)
                } else {
                    Text(otpToken.password)
                        .foregroundColor(.primary)
                }
            }
            .animation(.smooth, value: otpToken.codeDisplayString)
            .animation(.smooth, value: displayColor)
            .font(.headline.monospaced())
        }
    }
}
