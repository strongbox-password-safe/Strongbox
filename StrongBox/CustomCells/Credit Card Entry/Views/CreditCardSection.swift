import SwiftUI

struct CreditCardSection: View {
    @ObservedObject var viewModel: CreditCardEditorViewModel
    let isEditing: Bool
    let focusedField: CreditCardFocusBinding
    let onCopy: (String, String) -> Void
    
    var body: some View {
        CreditCardFormRow(icon: Image(systemName: "creditcard.fill"), title: "Credit Card Name", interactable: isEditing) {
            TextField("Credit Card Name", text: $viewModel.creditCardData.name)
                .focused(focusedField, equals: .name)
                .onChange(of: viewModel.creditCardData.name) { _ in
                    viewModel.markAsChanged()
                }
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.name, "Credit Card Name Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "person.fill"), title: "Cardholder Name", interactable: isEditing) {
            TextField("John Appleseed", text: $viewModel.creditCardData.cardholderName)
                .focused(focusedField, equals: .cardholderName)
                .onChange(of: viewModel.creditCardData.cardholderName) { _ in
                    viewModel.markAsChanged()
                }
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.cardholderName, "Cardholder Name Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "number"), title: "Card Number", interactable: isEditing) {
            CreditCardFormSecureInputView("1234 5678 9012 3456", text: $viewModel.creditCardData.number, isSecured: $viewModel.creditCardData.numberConcealed)
                .keyboardType(.numberPad)
                .focused(focusedField, equals: .number)
                .onChange(of: viewModel.creditCardData.number) { newValue in
                    let detectedType = CardDetection.detectCardType(newValue).type
                    viewModel.creditCardData.cardType = detectedType
                    
                    let useAmexFormat = detectedType == .americanExpress
                    viewModel.creditCardData.number = newValue.formattedAsCreditCardNumber(usingAmexFormat: useAmexFormat)
                    viewModel.markAsChanged()
                    
                }
        } trailingContent: {
            Button {
                viewModel.toggleNumberConcealed()
            } label: {
                Image(systemName: viewModel.creditCardData.numberConcealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 25, height: 25, alignment: .center)
        }
        .tappable(isTappable: !isEditing) {
            let numbersOnlyString = viewModel.creditCardData.number.onlyNumbers
            onCopy(numbersOnlyString, "Card Number Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "creditcard.fill"), title: "Card Type", interactable: isEditing) {
            Picker("", selection: $viewModel.creditCardData.cardType) {
                ForEach(CreditCardData.availableCardTypes(), id: \.self) { cardType in
                        Text(cardType.rawValue)
                            .tag(cardType)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(height: 25)
            .onChange(of: viewModel.creditCardData.cardType) { _ in
                viewModel.markAsChanged()
            }
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.cardType.rawValue, "Card Type Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "lock.shield.fill"), title: "CVV/CVC", interactable: isEditing) {
            CreditCardFormSecureInputView("123", text: $viewModel.creditCardData.verificationNumber, isSecured: $viewModel.creditCardData.verificationNumberConcealed)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .keyboardType(.numberPad)
                .focused(focusedField, equals: .verificationNumber)
                .onChange(of: viewModel.creditCardData.verificationNumber) { _ in
                    viewModel.markAsChanged()
                }
        } trailingContent: {
            Button {
                viewModel.toggleVerificationNumberConcealed()
            } label: {
                Image(systemName: viewModel.creditCardData.verificationNumberConcealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 25, height: 25, alignment: .center)
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.verificationNumber, "CVV/CVC Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "calendar"), title: "Expiry Date", interactable: isEditing) {
            TextField("MM / YY", text: $viewModel.creditCardData.expiryDate)
                .keyboardType(.numberPad)
                .onChange(of: viewModel.creditCardData.expiryDate) { newValue in
                    viewModel.creditCardData.expiryDate = newValue.formattedAsExpiryDate()
                    viewModel.markAsChanged()
                }
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.expiryDate, "Expiry Date Copied")
        }
        
        CreditCardFormRow(icon: Image(systemName: "calendar"), title: "Valid From", interactable: isEditing) {
            TextField("MM / YY", text: $viewModel.creditCardData.validFrom)
                .keyboardType(.numberPad)
                .onChange(of: viewModel.creditCardData.validFrom) { newValue in
                    viewModel.creditCardData.validFrom = newValue.formattedAsExpiryDate()
                    viewModel.markAsChanged()
                }
        }
        .tappable(isTappable: !isEditing) {
            onCopy(viewModel.creditCardData.validFrom, "Valid From Copied")
        }
    }
}
