import SwiftUI

extension View {
    
    
    func errorAlert(_ error: Binding<Error?>) -> some View {
        alert("Error", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { newValue in if !newValue { error.wrappedValue = nil } }
        )) {
            Button("OK") { error.wrappedValue = nil }
        } message: {
            Text(error.wrappedValue?.localizedDescription ?? "Unknown error")
        }
    }
}
