//
//  SaleOfferView.swift
//  Strongbox
//
//  Created by Strongbox on 12/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

#if os(iOS)
    import UIKit
#endif

struct SaleOfferView: View {
    var dismiss: (() -> Void)!
    var onLifetime: (() -> Void)!
    var redeem: (() -> Void)!
    var sale: Sale!
    var existingSubscriber: Bool

    var saleEndDate: Date {
        let inclusiveEndDate = Calendar.current.date(byAdding: .day, value: -1, to: sale.end)

        return inclusiveEndDate ?? Date()
    }

    static let endDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" 
        return formatter
    }()

    var body: some View {
        #if os(macOS)
            theBody
                .frame(minWidth: 450, minHeight: 450)
                .colorScheme(.dark)
        #else
            theBody
                .colorScheme(.dark)
        #endif
    }

    var theBody: some View {
        ZStack {
            Rectangle()
                .ignoresSafeArea()
                .foregroundStyle(Design.glowyGradient)

            content
        }
    }

    var content: some View {
        ZStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        imageView

                        VStack(spacing: 16) {
                            Text(existingSubscriber ? "sale_view_subscriber_title" : "sale_view_regular_title")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            if let title = sale.title {
                                Text(title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }

                            Text("sale_view_new_message")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                VStack(spacing: 12) {
                    Spacer()

                    VStack(spacing: 20) {
                        Text("sale_view_offer_ends_date_fmt \(saleEndDate, formatter: Self.endDateFormat)")
                            .font(.caption2)
                            .foregroundColor(.white)

                        if let promoCode = sale.promoCode {
                            HStack {
                                Text("Use Promo Code:")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text("\(promoCode)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        redeemButton

                        cancelButton
                    }
                }
            }
            .padding()
            #if os(iOS)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle")
                                .imageScale(.large)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                        .padding()
                }
                .padding()
            #endif
        }
        .edgesIgnoringSafeArea(.vertical)
    }

    @ViewBuilder
    var imageView: some View {
        #if os(iOS)
        FancyGlowingIconView(
            iconSize: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 120,
            showSparkles: true
        )
        #else
        FancyGlowingIconView(
            iconSize: 120,
            showSparkles: true
        )
        #endif
    }

    @ViewBuilder
    var redeemButton: some View {
        #if os(macOS)
            let buttonStartColor = Color(NSColor(hex: "#02AABD"))
            let buttonEndColor = Color(NSColor(hex: "#38EF7D"))
        #else
            let buttonStartColor = Color(UIColor(hex: "#02AABD"))
            let buttonEndColor = Color(UIColor(hex: "#38EF7D"))
        #endif
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: {
                redeem()
            }, label: {
                VStack {
                    Text(existingSubscriber ? "sale_view_subscriber_cta" : "sale_view_regular_cta")
                        .foregroundColor(.white)
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding()
                        .frame(minWidth: 0, maxWidth: 300)
                        .keyboardShortcut(.defaultAction)
                }
            })
            .buttonStyle(.glassProminent)
        } else {
            Button(action: {
                redeem()
            }, label: {
                VStack {
                    Text(existingSubscriber ? "sale_view_subscriber_cta" : "sale_view_regular_cta")
                        .foregroundColor(.white)
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(height: 56)
                        .frame(minWidth: 0, maxWidth: 300)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue, buttonEndColor
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                        .keyboardShortcut(.defaultAction)
                }
            })
            .buttonStyle(.plain)
        }
    }

    var cancelButton: some View {
        Button(action: { dismiss() }) {
            Text("generic_not_right_now")
                .foregroundColor(.white)
                .font(.subheadline.weight(.semibold))
                .frame(height: 40)
                .frame(minWidth: 0, maxWidth: 300)
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.plain)
    }
}

struct SubscriberSaleOffer_Previews: PreviewProvider {
    static var previews: some View {
        SaleOfferView(sale: Sale(startLondonNoonTimeInclusive: "2025-03-14", endLondonNoonTimeExclusive: "2025-03-18", title: "Black Friday Special", promoCode: "IRE25"), existingSubscriber: false)
    }
}

#if os(iOS)
    @objcMembers
    class SaleBannerView: UIControl {
        private let iconImageView = UIImageView(image: UIImage(systemName: "gift.fill"))
        private let titleLabel = UILabel()
        private let subtitleLabel = UILabel()
        private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.forward"))
        private let contentStack = UIStackView()
        private let textStack = UIStackView()

        @objc var titleText: String? {
            didSet {
                titleLabel.text = titleText
                updateAccessibilityLabel()
            }
        }

        @objc var subtitleText: String? {
            didSet {
                subtitleLabel.text = subtitleText
                subtitleLabel.isHidden = subtitleText?.isEmpty ?? true
                updateAccessibilityLabel()
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        private func commonInit() {
            let baseColor = UIColor.systemBlue
            if #available(iOS 13.0, *) {
                backgroundColor = UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? baseColor.withAlphaComponent(0.92) : baseColor
                }
            }
            else {
                backgroundColor = baseColor
            }

            tintColor = .white
            layer.cornerRadius = 26
            if #available(iOS 13.0, *) {
                layer.cornerCurve = .continuous
            }
            layer.masksToBounds = true

            iconImageView.tintColor = .systemYellow
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
            iconImageView.heightAnchor.constraint(equalToConstant: 32).isActive = true
            iconImageView.setContentHuggingPriority(.required, for: .horizontal)
            iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

            chevronImageView.tintColor = UIColor.white.withAlphaComponent(0.85)
            chevronImageView.contentMode = .scaleAspectFit
            chevronImageView.translatesAutoresizingMaskIntoConstraints = false
            chevronImageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
            chevronImageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
            chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
            chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            titleLabel.textColor = .white
            titleLabel.numberOfLines = 1
            titleLabel.adjustsFontForContentSizeCategory = true

            subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
            subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            subtitleLabel.numberOfLines = 2
            subtitleLabel.adjustsFontForContentSizeCategory = true
            subtitleLabel.isHidden = true

            textStack.axis = .vertical
            textStack.spacing = 2
            textStack.alignment = .leading
            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(subtitleLabel)

            let spacer = UIView()
            spacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

            contentStack.axis = .horizontal
            contentStack.alignment = .center
            contentStack.spacing = 12
            contentStack.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(iconImageView)
            contentStack.addArrangedSubview(textStack)
            contentStack.addArrangedSubview(spacer)
            contentStack.addArrangedSubview(chevronImageView)

            addSubview(contentStack)

            NSLayoutConstraint.activate([
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
                contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
                contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
            ])

            contentStack.isUserInteractionEnabled = false

            isAccessibilityElement = true
            accessibilityTraits.insert(.button)
            accessibilityIdentifier = "sale-banner-view"
        }

        override var isHighlighted: Bool {
            didSet {
                UIView.animate(withDuration: 0.15) {
                    self.alpha = self.isHighlighted ? 0.6 : 1.0
                }
            }
        }

        private func updateAccessibilityLabel() {
            let parts = [titleText, subtitleText?.isEmpty == false ? subtitleText : nil].compactMap { $0 }
            accessibilityLabel = parts.joined(separator: ". ")
        }
    }
#endif
