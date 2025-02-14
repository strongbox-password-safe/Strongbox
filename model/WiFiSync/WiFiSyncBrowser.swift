//
//  WiFiSyncBrowser.swift
//  WiFiSync-Client
//
//  Created by Strongbox on 09/12/2023.
//

import Network
import OSLog

extension Notification.Name {
    static let wifiBrowserResultsUpdated = Notification.Name("wifiBrowserResultsUpdated")
}

@objc
class WiFiSyncBrowser: NSObject, ObservableObject {
    @objc
    static var shared = WiFiSyncBrowser()

    static let browserQ: DispatchQueue = .init(label: "Wi-Fi-Browser-Queue")

    var browser: NWBrowser? = nil

    @objc var isRunning: Bool {
        browser != nil && !startInProgress && !stopInProgress
    }

    var stopInProgress = false
    var startInProgress = false

    @objc var networkPermissionsDenied = false
    @objc var lastError: String? = nil

    init(availableServers: [WiFiSyncServerConfig] = []) { 
        super.init()

        updateServersAndNotify(availableServers)
    }

    let availableBackingStore: ConcurrentMutableArray<WiFiSyncServerConfig> = ConcurrentMutableArray()

    @Published
    @objc
    var availableServers: [WiFiSyncServerConfig] = [] {
        didSet {
            NotificationCenter.default.post(name: .wifiBrowserResultsUpdated, object: nil)
        }
    }

    @objc
    func startBrowsing(_ forceStopFirst: Bool = false, completion: @escaping ((Bool) -> Void)) {
        let prefs = CrossPlatformDependencies.defaults().applicationPreferences

        guard StrongboxProductBundle.supportsWiFiSync, !prefs.disableWiFiSyncClientMode else {
            swlog("🔴 Bundle does not support WiFi sync! Do not call Browser start()")
            return
        }

        if startInProgress {
            swlog("WiFiSyncBrowser::startBrowsing Start in progress so will not start...")
            completion(true) 
            return
        }

        if forceStopFirst {
            swlog("WiFiSyncBrowser::startBrowsing with Force Start - Stopping...")
            stopBrowsing { [weak self] in
                guard let self else { return }

                startBrowsingForReal(completion: completion)
            }
        } else if browser != nil {
            swlog("WiFiSyncBrowser::startBrowsing - Browser already running ignoring start request")
            completion(true)
        } else {
            swlog("WiFiSyncBrowser::startBrowsing - not already running. Starting...")
            startBrowsingForReal(completion: completion)
        }
    }

    func startBrowsingForReal(completion: (Bool) -> Void) {
        startInProgress = true
        lastError = nil
        networkPermissionsDenied = false

        let parameters = NWParameters()

        
        
        
        

        parameters.includePeerToPeer = false

        

        parameters.prohibitedInterfaceTypes = [.cellular]

        browser = NWBrowser(for: .bonjour(type: WiFiSyncConstants.ServiceType, domain: nil), using: parameters)

        guard let browser else {
            startInProgress = false

            swlog("🔴 Could not create browser!")

            completion(false)
            return
        }

        browser.stateUpdateHandler = browserStateUpdateHandler
        browser.browseResultsChangedHandler = browseResultsChangedHandler

        browser.start(queue: WiFiSyncBrowser.browserQ)

        swlog("WiFiSyncBrowser::startBrowsing EXIT")

        completion(true)

        startInProgress = false
    }

    @objc
    func stopBrowsing(completion: (() -> Void)? = nil) {
        swlog("WiFiSyncBrowser::stopBrowsing ENTER")

        if stopInProgress {
            swlog("WiFiSyncBrowser::stopBrowsing Stop already in progress, ignoring duplicate request")
            swlog("WiFiSyncBrowser::stopBrowsing EXIT")
            completion?()
            return
        }

        stopInProgress = true

        if let browser {
            if browser.state != .cancelled {
                swlog("WiFiSyncBrowser::stopBrowsing - Not already cancelled or failed so cancelling and waiting a bit now.")
                browser.cancel()

                WiFiSyncBrowser.browserQ.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }

                    swlog("WiFiSyncBrowser::stopBrowsing - Wait for cancel done... calling completion")

                    self.browser = nil

                    self.updateServersAndNotify()

                    completion?()

                    stopInProgress = false

                    swlog("WiFiSyncBrowser::stopBrowsing EXIT")
                }

                return
            } else {
                swlog("WiFiSyncBrowser::stopBrowsing - Already cancelled so NOP.")
                self.browser = nil
            }
        } else {
            swlog("WiFiSyncBrowser::stopBrowsing - Already Nil so NOP.")
        }

        updateServersAndNotify()

        completion?()

        stopInProgress = false

        swlog("WiFiSyncBrowser::stopBrowsing EXIT")
    }

    

    @objc
    func serverIsPresent(_ serverName: String) -> Bool {
        getServerConfig(serverName) != nil
    }

    @objc
    func getServerConfig(_ serverName: String) -> WiFiSyncServerConfig? {
        availableBackingStore.snapshot.first { server in
            server.name == serverName
        }
    }

    func getEndpoint(_ serverName: String) -> NWEndpoint? {
        getServerConfig(serverName)?.endpoint
    }

    func browserStateUpdateHandler(_ newState: NWBrowser.State) {
        switch newState {
        case let .failed(error):
            lastError = String(describing: error)

            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                
                swlog("Browser failed with \(error), restarting")
                startBrowsing(true) { success in
                    swlog("Browser restarted with \(success) after defunct connection")
                }
            } else {
                swlog("Browser failed with \(error), stopping")
                stopBrowsing()
            }
        case let .waiting(error):
            lastError = String(describing: error)

            

            if case let .dns(dNSServiceErrorType) = error, dNSServiceErrorType == kDNSServiceErr_PolicyDenied {
                networkPermissionsDenied = true
                stopBrowsing() 
            }
        case .ready:
            swlog("🟢🟢🟢🟢 browserStateUpdateHandler initial results ready.")
        case .cancelled: 
            swlog("browserStateUpdateHandler cancelled.")
            stopBrowsing()
        default:
            break
        }

        updateServersAndNotify()
    }

    func browseResultsChangedHandler(_: Set<NWBrowser.Result>, _: Set<NWBrowser.Result.Change>) {












































        updateServersAndNotify()
    }

    func updateServersAndNotify(_ explicit: [WiFiSyncServerConfig]? = nil) {
        availableBackingStore.removeAllObjects()

        if let explicit {
            availableBackingStore.addObjects(from: explicit)
        } else if let browser {


            let newServers = browser.browseResults.compactMap { result in
                if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = result.endpoint {

                    return WiFiSyncServerConfig(name: name, endpoint: result.endpoint)
                } else {
                    swlog("🔴 Could not add browse result: \(String(describing: result))")
                    return nil
                }
            }

            availableBackingStore.addObjects(from: newServers)
        }

        

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            availableServers = availableBackingStore.snapshot
        }
    }
}
