import SwiftUI

struct FeaturesList: View {
    let isSimple: Bool

    var body: some View {
        if isSimple {
            VStack(spacing: 12) {
                ForEach(buildFeatures()) { appFeature in
                    SimpleFeatureRow(feature: appFeature)
                }
            }
        } else {
            VStack(spacing: 6) {
                ForEach(buildFeatures()) { appFeature in
                    FeatureRow(feature: appFeature)
                }
            }
        }
    }

    func buildFeatures() -> [Feature] {
        var features: [Feature] = []

        
        if !Utils.isiPadPro {
            features.append(
                Feature(
                    icon: "key.fill",
                    title: "YubiKey",
                    subtitle: NSLocalizedString(
                        "upgrade_vc_feature_subtitle_yubikey",
                        comment: "Use a YubiKey as a second factor"
                    )
                )
            )
        }

        
        let isFaceID = BiometricsManager.sharedInstance().isFaceId()
        let biometricIcon = isFaceID ? "faceid" : "touchid"
        let biometricTitleKey = isFaceID
            ? "upgrade_vc_feature_face_id_pin_code"
            : "upgrade_vc_feature_touch_id_pin_code"
        features.append(
            Feature(
                icon: biometricIcon,
                title: NSLocalizedString(
                    biometricTitleKey,
                    comment: "Face/Touch ID & PIN Code Unlock"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_biometric",
                    comment: "Super Fast, Secure & Convenient"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "paintbrush.fill",
                title: NSLocalizedString(
                    "upgrade_vc_feature_custom_app_icon",
                    comment: "Custom App Icons"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_custom_app_icon",
                    comment: "Customize your Strongbox"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "arrow.merge",
                title: NSLocalizedString(
                    "upgrade_vc_feature_compare_and_merge",
                    comment: "Compare & Merge"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_compare_and_merge",
                    comment: "View & Combine Revisions"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "heart.circle",
                title: NSLocalizedString(
                    "upgrade_vc_feature_support_indie",
                    comment: "Support Indie Development"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_support_indie",
                    comment: "Help us stay awesome!"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "questionmark.circle.fill",
                title: NSLocalizedString(
                    "upgrade_vc_feature_support",
                    comment: "Premium Support"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_support",
                    comment: "We're here for you"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "doc.text.magnifyingglass",
                title: NSLocalizedString(
                    "upgrade_vc_feature_auditing",
                    comment: "Advanced Auditing"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_auditing",
                    comment: "HIBP & Similar Passwords"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "globe",
                title: NSLocalizedString(
                    "upgrade_vc_feature_favicon_downloader",
                    comment: "Favicon Downloader"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_favicon_downloader",
                    comment: "Make your entries stand out"
                )
            )
        )

        
        features.append(
            Feature(
                icon: "bolt.circle.fill",
                title: NSLocalizedString(
                    "upgrade_vc_feature_offline_editing",
                    comment: "Offline Editing"
                ),
                subtitle: NSLocalizedString(
                    "upgrade_vc_feature_subtitle_offline_editing",
                    comment: "Edit Offline, Sync Later"
                )
            )
        )

        return features
    }

}



struct FeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.labelPrimary)

                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundColor(.labelSecondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(Color.sbWhite)
                .sbShadow()
        )
    }
}



struct SimpleFeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title2)
                .frame(width: 32, height: 32)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.labelPrimary)

                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundColor(.labelSecondary)
            }

            Spacer()
        }
    }
}

struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}
