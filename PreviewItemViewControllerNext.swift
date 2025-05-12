import SwiftUI
import UIKit

@objc final class PreviewItemViewControllerNext: UIViewController {
    private let hostingController: UIHostingController<PreviewItemView>

    
    @objc init(item: Node, model: Model) {
        self.hostingController = UIHostingController(rootView: PreviewItemView(item: item, model: model))
        super.init(nibName: nil, bundle: nil)
    }

    @objc required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        
        let targetSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = hostingController.sizeThatFits(in: targetSize)
        preferredContentSize = size
    }
}
