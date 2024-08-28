//
//  HardwareKeySettingsView.swift
//  MacBox
//
//  Created by Strongbox on 13/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

struct HardwareKeySettingsView: View {
    @State var keyCachingEnabled: Bool = false
    @State var autoFillRefreshSuppressed: Bool = true
    @State var cacheChallengeDurationSecs: Int = 3600
    @State var challengeRefreshIntervalSecs: Int = 0

    func notifySettingChanged() {
        onSettingsChanged?(keyCachingEnabled, cacheChallengeDurationSecs, challengeRefreshIntervalSecs, autoFillRefreshSuppressed)
    }

    var onSettingsChanged: ((Bool, Int, Int, Bool) -> Void)? = nil
    var completion: (() -> Void)? = nil

    let challengeDurationIntervals = [-1, 
                                      0, 
                                      120,
                                      300,
                                      600,
                                      1800,
                                      3600,
                                      4 * 3600,
                                      8 * 3600,
                                      12 * 3600,
                                      24 * 3600,
                                      2 * 24 * 3600,
                                      3 * 24 * 3600,
                                      5 * 24 * 3600,
                                      7 * 24 * 3600,
                                      14 * 24 * 3600]

    let challengeRefreshIntervals = [0, 
                                     1800,
                                     3600,
                                     8 * 3600,
                                     12 * 3600,
                                     24 * 3600,
                                     2 * 24 * 3600,
                                     3 * 24 * 3600,
                                     5 * 24 * 3600,
                                     7 * 24 * 3600,
                                     14 * 24 * 3600]

    fileprivate func getFriendlyIntervalString(_ interval: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute, .second]

        return formatter.string(from: TimeInterval(interval)) ?? "generic_unknown"
    }

    func titleForChallengeRefreshInterval(interval: Int) -> String {
        if interval == 0 {
            return NSLocalizedString("interval_on_every_save", comment: "On Every Save")
        } else {
            return getFriendlyIntervalString(interval)
        }
    }

    func titleForCacheDuration(interval: Int) -> String {
        if interval == 0 {
            return NSLocalizedString("generic_duration_forever", comment: "Forever")
        } else if interval < 0 {
            return NSLocalizedString("until_app_termination", comment: "until App Termination")
        } else {
            return getFriendlyIntervalString(interval)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section {
                    Toggle("setting_response_caching_title", isOn: $keyCachingEnabled.onChange { _ in notifySettingChanged() })
                        .toggleStyle(.switch)

                    Picker("setting_cache_response_for_period_of_time", selection: $cacheChallengeDurationSecs.onChange { _ in notifySettingChanged() }) {
                        ForEach(challengeDurationIntervals, id: \.self) {
                            Text(titleForCacheDuration(interval: $0))
                        }
                    }
                    .disabled(!keyCachingEnabled)
                } header: {
                    Text("challenge_response_caching_header")
                    #if os(macOS)
                        .font(.headline)
                    #endif
                } footer: {
                    Text("challenge_response_caching_footer")
                    #if os(macOS)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    #endif
                }

                #if os(macOS)
                    Spacer()
                    Divider()
                    Spacer()
                #endif

                Section {
                    Picker("refresh_challenge_interval", selection: $challengeRefreshIntervalSecs.onChange { _ in notifySettingChanged() }) {
                        ForEach(challengeRefreshIntervals, id: \.self) {
                            Text(titleForChallengeRefreshInterval(interval: $0))
                        }
                    }

                    Toggle("autofill_refresh_challenge_suppressed", isOn: $autoFillRefreshSuppressed.onChange { _ in notifySettingChanged() })
                        .toggleStyle(.switch)
                } header: {
                    Text("challenge_refreshing_header")
                    #if os(macOS)
                        .font(.headline)
                    #endif
                } footer: {
                    Text("challenge_refreshing_footer")
                    #if os(macOS)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    #endif
                }
            }

            #if os(macOS)
                Button {
                    completion?()
                } label: {
                    Text("generic_verb_close")
                }
                .keyboardShortcut(.defaultAction)
            #endif
        }
        .controlSize(.large)
        #if os(iOS)
            .navigationTitle("nav_title_hardware_key_settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        completion?()
                    }) {
                        Text("generic_verb_close")
                    }
                }
            }
        #endif
        #if os(macOS)

        .scenePadding()
        #endif
    }
}

#Preview {
    #if os(macOS)
        HardwareKeySettingsView()
    #else
        NavigationView {
            HardwareKeySettingsView()
        }
    #endif
}
