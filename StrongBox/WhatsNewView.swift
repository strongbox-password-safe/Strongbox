//
//  WhatsNewView.swift
//
//
//  Created by Strongbox on 22/12/2024.
//

import Foundation
import MarkdownUI
import SwiftUI

struct WhatsNewView: View {
    let messages: [WhatsNewMessage]
    var dismiss: () -> Void

    var body: some View {
        VStack {
            VStack {
                Group {
                    HStack {
                        Image(systemName: "gift")
                            .font(Font.system(size: 30, weight: .bold))
                            .minimumScaleFactor(0.2)

                        Text("whats_new_title")
                            .font(Font.system(size: 40, weight: .bold))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .green, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                Text("whats_new_subtitle")
                    .font(.subheadline)
            }
            .padding([.horizontal, .top])

            List {
                ForEach(messages) { message in
                    Section {
                        Markdown(message.markdownBody)
                    }
                    header: {
                        Text(message.version)
                            .font(.headline)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Text("OK")
                    .font(.headline)
            }
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            }
            label: {
                Image(systemName: "x.circle")
                    .foregroundStyle(.gray)
                    .font(.system(size: 22))
            }
            .padding([.trailing, .top])
        }
    }
}

#Preview {
    let markdownBody =
        """
        #### Apple Watch App
        - You can now sync individual entries from your databases to your Apple Watch. 
        - Install the Strongbox App on your watch to get started...

        #### 2FA Code Improvements 
        - We've improved 2FA Code display and animation. We hope you'll like it! 

        """

    let markdownBody2 =
        """
        #### Some Other Feature
        - You can now sync individual entries from your databases to your Apple Watch. 
        - Install the Strongbox App on your watch to get started...

        #### And Also... 
        - We've improved 2FA Code display and animation. We hope you'll like it! 

        """

    let messages: [WhatsNewMessage] = [
        WhatsNewMessage(sequenceNumber: 0, version: "1.60.29", markdownBody: markdownBody2),
        WhatsNewMessage(sequenceNumber: 1, version: "1.60.30", markdownBody: markdownBody),
    ]

    return WhatsNewView(messages: messages.reversed()) {}
}
