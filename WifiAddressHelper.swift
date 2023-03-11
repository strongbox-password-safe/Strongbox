//
//  WifiAddressHelper.swift
//  Strongbox-iOS
//
//  Created by Strongbox on 05/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

enum Network: String {
    case wifi = "en0"
    case cellular = "pdp_ip0"
    //... case ipv4 = "ipv4"
    //... case ipv6 = "ipv6"
}

class WifiAddressHelper : NSObject {
    @objc class func getWifiAddress() -> String? {
        return getAddress(for: .wifi)
    }
    
    class func getAddress(for network: Network) -> String? {
        var address: String?
        
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                
                let name = String(cString: interface.ifa_name)
                if name == network.rawValue {
                    
                    
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


