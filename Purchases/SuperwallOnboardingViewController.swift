import UIKit
import SuperwallKit



@objc class SuperwallOnboardingViewController: UIViewController {

    private var onDone: (() -> Void)?
    private var paywallViewController: PaywallViewController?
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    @objc static func make(onDone: @escaping () -> Void) -> SuperwallOnboardingViewController {
        let vc = SuperwallOnboardingViewController()
        vc.onDone = onDone
        vc.modalPresentationStyle = .fullScreen
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        activityIndicator.startAnimating()

        
        loadPaywall()
    }

    private func loadPaywall() {
        Superwall.shared.getPaywall(
            forPlacement: SuperwallCampaign.onboarding.campaignValue,
            params: nil,
            paywallOverrides: nil,
            delegate: self
        ) { [weak self] paywall, skippedReason, error in
            DispatchQueue.main.async {
                self?.handlePaywallResult(paywall: paywall, skippedReason: skippedReason, error: error)
            }
        }
    }

    private func handlePaywallResult(paywall: PaywallViewController?, skippedReason: PaywallSkippedReason?, error: Error?) {
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()

        if let paywall = paywall {
            embedPaywall(paywall)
        } else {
            
            if let skippedReason = skippedReason {
                swlog("Superwall onboarding paywall skipped: \(skippedReason)")
            }
            if let error = error {
                swlog("Superwall onboarding paywall error: \(error)")
            }
            finishOnboarding()
        }
    }

    private func embedPaywall(_ paywall: PaywallViewController) {
        paywallViewController = paywall

        addChild(paywall)
        paywall.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(paywall.view)

        NSLayoutConstraint.activate([
            paywall.view.topAnchor.constraint(equalTo: view.topAnchor),
            paywall.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paywall.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            paywall.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        paywall.didMove(toParent: self)
    }

    private func finishOnboarding() {
        
        if let paywallVC = paywallViewController {
            paywallVC.willMove(toParent: nil)
            paywallVC.view.removeFromSuperview()
            paywallVC.removeFromParent()
            paywallViewController = nil
        }

        dismiss(animated: true) { [weak self] in
            self?.onDone?()
        }
    }
}



extension SuperwallOnboardingViewController: PaywallViewControllerDelegate {
    func paywall(
        _ paywall: PaywallViewController,
        didFinishWith result: PaywallResult,
        shouldDismiss: Bool
    ) {
        switch result {
        case .purchased, .restored:
            swlog("Superwall onboarding: User subscribed")
        case .declined:
            swlog("Superwall onboarding: User declined")
        }

        if shouldDismiss {
            finishOnboarding()
        }
    }

    func paywall(
        _ paywall: PaywallViewController,
        loadingStateDidChange loadingState: PaywallLoadingState
    ) {
        
    }
}
