import SwiftUI

extension View {
    func gradientIfPossible(color: Color) -> some View {
        self
            .modify { view in
                if #available(iOS 16, *) {
                    view.foregroundStyle(color.gradient)
                } else {
                    view.foregroundStyle(color)
                }
            }
    }

    @ViewBuilder
    func sbShadow() -> some View {
        self
            .shadow(color: (Color("shadowGrey")).opacity(0.2), radius: 4)
    }
}

struct BasicSquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.bouncy, value: configuration.isPressed)
            .hoverEffect(.lift)
    }
}
