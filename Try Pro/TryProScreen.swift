import SwiftUI
import StrongboxPurchases

struct TryProScreen: View {
    var onDone: () -> (Void)
    
    @StateObject private var model: SBPaywallModel = .init(paywallType: "")
    @State private var showSuccessAlert = false
    
    var body: some View {
        ScrollView {
            VStack {
                RoundedRectangle(cornerRadius: 12)
                    .frame(height: 200)
                    .foregroundStyle(Color.clear)
                    .background {
                        Image("card-ios")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                
                title
                
                Text("paywall_try")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                
                if let subtitleText = model.subtitleText {
                    Text(subtitleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.labelSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }

                if let billingText = model.billingText {
                    Text(billingText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.labelTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }
                
                FeaturesList(isSimple: false)
            }
            .padding()
        }
        .background(Color.bg)
        .safeAreaInset(edge: .bottom, content: {
            VStack(spacing: 8) {
                Text("paywall_no_payment_today")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.labelSecondary)
                
                redeemButton
                cancelButton
            }
            .padding([.horizontal, .top])
            .padding(.top)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                Rectangle()
                    .frame(minHeight: 280)
                    .foregroundStyle(
                        LinearGradient(colors: [
                            Color.sbWhite.opacity(0),
                            Color.sbWhite.opacity(1)
                        ], startPoint: .top, endPoint: .center)
                    )
                    .sbShadow()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            
           .errorAlert($model.error)
           
           .alert("paywall_thanks", isPresented: $showSuccessAlert) {
               Button("generic_get_started") {
                   dismiss()
               }
           } message: {
               Text("paywall_got_pro")
           }
        })
    }
    
    private func redeem() {
        model.purchaseYearly { error in
            if error == nil {
                showSuccessAlert = true
            }
        }
    }
    
    private func dismiss() {
        onDone()
    }
    
    var title: some View {
        HStack(spacing: 8) {
            Text("Strongbox")
                .font(.title.weight(.semibold))
                .foregroundStyle(.labelPrimary)

            Text("PRO")
                .font(
                    .expanded(size: 24, weight: .semibold)
                )
                .foregroundStyle(Color.white)
                .padding(4)
                .padding(.horizontal, 8)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .gradientIfPossible(color: .blue)
                        .sbShadow()
                }
        }
    }
    
    @ViewBuilder
    var redeemButton: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: {
                redeem()
            }, label: {
                VStack {
                    Text("paywall_start")
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
                    Text("paywall_start")
                        .foregroundColor(.white)
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(height: 56)
                        .frame(minWidth: 0, maxWidth: 300)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue, Color.teal
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
                .foregroundColor(.labelTertiary)
                .font(.subheadline.weight(.semibold))
                .frame(height: 40)
                .frame(minWidth: 0, maxWidth: 300)
                .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TryProScreen(onDone: { })
}
