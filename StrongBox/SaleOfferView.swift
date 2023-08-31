//
//  SaleOfferView.swift
//  Strongbox
//
//  Created by Strongbox on 12/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import SwiftUI

struct SaleOfferView: View {
    var dismiss: (() -> Void)!
    var onLifetime: (() -> Void)!
    var redeem: (() -> Void)!
    var saleEndDate: Date
    var existingSubscriber: Bool

    static let endDateFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" 
        return formatter
    }()

    var body: some View {
        #if os(macOS)
            theBody
                .frame(minWidth: 450, minHeight: 450)
        #else
            theBody
        #endif
    }

    var theBody: some View {
        #if os(macOS)
            let startColor = Color(NSColor(hex: "#2E3192"))
            let endColor = Color(NSColor(hex: "#1BFFFF"))

            let buttonStartColor = Color(NSColor(hex: "#02AABD"))
            let buttonEndColor = Color(NSColor(hex: "#38EF7D"))

            let cancelButtonStartColor = Color(NSColor(hex: "#2E3192"))
            let cancelButtonEndColor = Color(NSColor(hex: "#2E3192"))
        #else
            let startColor = Color(UIColor(hex: "#2E3192"))
            let endColor = Color(UIColor(hex: "#1BFFFF"))

            let buttonStartColor = Color(UIColor(hex: "#02AABD"))
            let buttonEndColor = Color(UIColor(hex: "#38EF7D"))

            let cancelButtonStartColor = Color(UIColor(hex: "#2E3192"))
            let cancelButtonEndColor = Color(UIColor(hex: "#2E3192"))
        #endif

        return RadialGradient(gradient: Gradient(colors: [startColor, endColor]),
                              center: .center, startRadius: 2, endRadius: 650)
            .edgesIgnoringSafeArea(.vertical)
            .overlay(
                ZStack {
                    VStack(spacing: 20) {
                        Spacer()

                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                let image = Image(systemName: "gift").font(.system(size: 72))

                                #if os(macOS)
                                    if #available(macOS 12.0, *) {
                                        image
                                            .foregroundStyle(
                                                .linearGradient(colors: [.yellow, .pink], startPoint: .top, endPoint: .bottomTrailing)
                                            )
                                    } else {
                                        image.foregroundColor(.yellow)
                                    }

                                #else
                                    if #available(iOS 15.0, *) {
                                        image
                                            .foregroundStyle(
                                                .linearGradient(colors: [.yellow, .pink], startPoint: .top, endPoint: .bottomTrailing)
                                            )
                                    } else {
                                        image.foregroundColor(.yellow)
                                    }
                                #endif
                                Text(existingSubscriber ? "sale_view_subscriber_title" : "sale_view_regular_title")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(existingSubscriber ? "sale_view_subscriber_message" : "sale_view_regular_message")
                                    .multilineTextAlignment(.center)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        VStack(spacing: 12) {
                            VStack(spacing: 20) {
                                Button(action: {
                                    redeem()
                                }, label: {
                                    Text(existingSubscriber ? "sale_view_subscriber_cta" : "sale_view_regular_cta")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .frame(height: 56)
                                        .frame(minWidth: 0, maxWidth: 300)
                                        .background(LinearGradient(gradient: Gradient(colors: [buttonStartColor, buttonEndColor]),
                                                                   startPoint: .topLeading,
                                                                   endPoint: .bottomTrailing))
                                        .shadow(radius: 5)
                                        .cornerRadius(10)
                                        .keyboardShortcut(.defaultAction)
                                })
                                .buttonStyle(.plain)

                                Button(action: { dismiss() }) {
                                    Text("generic_not_right_now")
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                        .frame(height: 40)
                                        .frame(minWidth: 0, maxWidth: 300)
                                        .background(LinearGradient(gradient: Gradient(colors: [cancelButtonStartColor, cancelButtonEndColor]),
                                                                   startPoint: .topLeading,
                                                                   endPoint: .bottomTrailing))
                                        .shadow(radius: 5)
                                        .cornerRadius(10)
                                        .keyboardShortcut(.cancelAction)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("sale_view_offer_ends_date_fmt \(saleEndDate, formatter: Self.endDateFormat)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Button(action: { onLifetime() }, label: {
                            Text("sale_view_looking_for_lifetime")
                                .foregroundColor(.white)
                                .font(.caption)
                                .padding()
                        })
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
                        }
                        .padding(8)
                    #endif
                }
                .edgesIgnoringSafeArea(.vertical)
            )
    }
}

struct SubscriberSaleOffer_Previews: PreviewProvider {
    static var previews: some View {
        SaleOfferView(saleEndDate: Date(), existingSubscriber: false)
    }
}
