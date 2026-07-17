import Foundation
import UIKit

class EmptyDetailsViewController: UIViewController {
    @IBOutlet weak var toggleButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        toggleButton.isHidden = true
    }

    
    @IBAction func didToggle(_ sender: Any) {
        
        self.splitViewController?.preferredDisplayMode = .oneBesideSecondary
    }
}
