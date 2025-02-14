//
//  WifiAddressHelper.swift
//  Strongbox-iOS
//
//  Created by Strongbox on 05/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class WifiAddressHelper: NSObject {
    @objc class func getDebugAfInetAddresses() -> [String: String] {
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            swlog("🔴 Could not getifaddrs or firstAddr")
            return [:]
        }

        var addresses: [String: String] = [:]

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) { 
                
                let interfaceName = String(cString: interface.ifa_name)

                if interfaceName.starts(with: "utun") || interfaceName.starts(with: "lo") {

                    continue
                }

                

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)

                let address = String(cString: hostname)
                let up = ((interface.ifa_flags & UInt32(IFF_UP)) == IFF_UP)

                addresses[interfaceName] = String(format: "%@ %@", up ? "U" : "D", address)
            } else {

            }
        }
        freeifaddrs(ifaddr)



        return addresses
    }

    @objc class func getWifiAddress() -> String? {
        var address: String?

        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    

                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
}


