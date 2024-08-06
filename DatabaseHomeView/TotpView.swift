//
//  TotpView.swift
//  Strongbox
//
//  Created by Strongbox on 29/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Combine
import SwiftUI

struct TotpView: View {
    var totp: OTPToken

    @State private var totpString: String? = nil
    @State private var totpColor: Color = .blue
    @State private var animationOpacity = 1.0

    #if DEBUG
        var previewDummyTestTimer: AnyPublisher<Date, Never> = Combine.Empty<Date, Never>(completeImmediately: false).eraseToAnyPublisher()
    #endif

    var body: some View {
        Text(totpString ?? "")
            .foregroundStyle(totpColor)
            .opacity(animationOpacity)
            .onAppear(perform: {
                updateTotp()
            })
            .onReceive(NotificationCenter.default.publisher(for: .centralUpdateOtpUi, object: nil)) { _ in
                updateTotp()
            }
        #if DEBUG
            .onReceive(previewDummyTestTimer) { _ in
                updateTotp()
            }
        #endif
    }

    func updateTotp() {
        totpString = totp.codeDisplayString

        if let color = totp.color {
            #if os(iOS)
                totpColor = Color(uiColor: color)
            #else
                totpColor = Color(nsColor: color)
            #endif
        } else {
            totpColor = .blue
        }

        if totp.remainingSeconds < 10 {
            withAnimation(.easeOut(duration: 0.65).repeatForever()) {
                animationOpacity = 0.35
            }
        } else {
            withAnimation {
                animationOpacity = 1
            }
        }
    }
}

#if DEBUG
    #Preview {
        var timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()

        return TotpView(totp: OTPToken(url: URL(string: "otpauth:
    }
#endif
