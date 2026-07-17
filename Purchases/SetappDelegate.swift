import Setapp

class SetappSubscriptionManagerDelegate: SetappManagerDelegate {

  public var onUpdate: ((Bool) -> Void)?

  init() {
    SetappManager.shared.delegate = self
  }

  
  func setappManager(
    _ manager: SetappManager,
    didUpdateSubscriptionTo newSetappSubscription: SetappSubscription
  ) {
      print("[Setapp] did update subscription:", newSetappSubscription.isActive)
      onUpdate?(newSetappSubscription.isActive)
  }

  func hasValidSetappSubscription() -> Bool {
    SetappManager.shared.subscription?.isActive ?? false
  }
}
