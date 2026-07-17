import Network

@objc @objcMembers
@available(iOS 14.0, *)
public class LocalNetworkPermissionChecker: NSObject {
    
    private var browser: NWBrowser?
    private var netService: NetService?
    private var completion: ((Bool) -> Void)?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        
        let browser = NWBrowser(for: .bonjour(type: "_sb-wifi-sync._tcp", domain: nil), using: parameters)
        self.browser = browser
        
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                print(error.localizedDescription)
            case .ready, .cancelled:
                break
            case let .waiting(error):
                print("Local network permission has been denied: \(error)")
                self.reset()
                self.completion?(false)
            default:
                break
            }
        }
        
        self.netService = NetService(domain: "", type:"_sb-wifi-sync._tcp", name: "LocalNetworkPrivacy", port: 1100)
        self.netService?.delegate = self
        
        self.browser?.start(queue: .main)
        self.netService?.publish()
    }
    
    private func reset() {
        self.browser?.cancel()
        self.browser = nil
        self.netService?.stop()
        self.netService = nil
    }
}

@available(iOS 14.0, *)
extension LocalNetworkPermissionChecker : NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        self.reset()
        print("Local network permission has been granted")
        completion?(true)
    }
}
