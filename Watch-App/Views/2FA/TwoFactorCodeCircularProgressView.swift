//
//  TwoFactorCodeCircularProgressView.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Combine
import SwiftUI

@available(iOS 16.0, *)
struct TwoFactorCodeCircularProgressView: View {
    var totp: OTPToken
    var radius: CGFloat
    var updateMode: TwoFactorUpdateMode
    var hideCountdownDigits: Bool

    @State private var totpSeconds: String = ""
    @State private var totpProgress: Double = 0.0
    @State private var totpColor: Color = .blue

    var body: some View {
        let circleStrokeWidth = radius / 8
        let fontSize = radius / 3.2

        ZStack(alignment: .center) {
            Circle()
                .stroke(lineWidth: circleStrokeWidth)
                .foregroundStyle(totpColor.opacity(0.4))

            if #available(macOS 13.0, iOS 18.0, watchOS 11.0, *) {
                Circle()
                    .trim(from: 0.0, to: min(totpProgress, 1.0))
                    .stroke(totpColor.gradient, style: StrokeStyle(lineWidth: circleStrokeWidth, lineCap: .round, lineJoin: .miter))
                    .rotationEffect(.degrees(270))
                    .shadow(radius: 2)
                    .animation(.linear, value: totpProgress)
            } else {
                Circle()
                    .trim(from: 0.0, to: min(totpProgress, 1.0))
                    .stroke(totpColor, style: StrokeStyle(lineWidth: circleStrokeWidth, lineCap: .round, lineJoin: .miter))
                    .rotationEffect(.degrees(270))
                    .shadow(radius: 2)
                    .animation(.linear, value: totpProgress)
            }

            if !hideCountdownDigits {
                if #available(macOS 13.0, *) {
                    let secs = Text(totpSeconds)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))
                        .font(Font.custom("DSEG7ClassicMini-Bold", size: fontSize))

                    if totpSeconds.hasPrefix("1") {
                        secs.padding(.leading, -(fontSize / 2.5))
                    } else {
                        secs
                    }
                } else {
                    let secs = Text(totpSeconds)
                        .lineLimit(1)
                        
                        .font(Font.custom("DSEG7ClassicMini-Bold", size: fontSize))

                    if totpSeconds.hasPrefix("1") {
                        secs.padding(.leading, -(fontSize / 2.5))
                    } else {
                        secs
                    }
                }
            }
        }
        .padding(radius / 10)
        .frame(width: radius, height: radius)
        .animation(.default, value: totpSeconds)
        .onLoad { updateTotp() }
        .twoFactorUpdater(mode: updateMode, onUpdate: updateTotp)
    }

    func updateTotp() {
        totpSeconds = String(format: "%d", totp.remainingSeconds)

        totpProgress = totp.progress

        if let color = totp.color {
            #if os(iOS) || os(watchOS)
                totpColor = Color(uiColor: color)
            #else
                totpColor = Color(nsColor: color)
            #endif
        } else {
            totpColor = .blue
        }
    }
}

#if DEBUG
    @available(iOS 16.0, *)
    #Preview {
        let otpAuthUrl = "otpauth:
        let token = OTPToken(url: URL(string: otpAuthUrl))!

        return VStack {
            TwoFactorCodeCircularProgressView(totp: token, radius: 50, updateMode: .automatic, hideCountdownDigits: true)
        }
    }
#endif
