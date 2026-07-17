import SwiftUI

@objc class TryProViewController: UIViewController {
    private var host: UIHostingController<TryProScreen>
    
    @objc class func make(
        onDone: @escaping () -> (Void)
    ) -> TryProViewController {
        self.init(onDone: onDone)
    }
    
    required init(
        onDone: @escaping () -> (Void)
    ) {
        self.host = .init(rootView: TryProScreen(onDone: onDone))
        super.init(nibName: nil, bundle: nil)
        self.add(host)
    }
    
    required init(coder: NSCoder) {
        fatalError("unavailable")
    }
}

extension UIViewController {
    func add(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            view.bottomAnchor.constraint(equalTo: child.view.bottomAnchor),
            view.rightAnchor.constraint(equalTo: child.view.rightAnchor)
        ]
        
        NSLayoutConstraint.activate(constraints)
        child.didMove(toParent: self)
    }
}
