//
//  HTTPRequest.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 10.05.20.
//

import Foundation
import PerfectHTTP

internal extension HTTPRequest {
    var host: String {
        var hostString: String
        let forwardedForHeader = self.header(.xForwardedFor) ?? ""
        if forwardedForHeader.isEmpty || !WebHookRequestHandler.hostWhitelistUsesProxy {
            hostString = self.remoteAddress.host
        } else {
            if forwardedForHeader.contains(",") {
                hostString = forwardedForHeader.components(separatedBy: ",").first!.trimmingCharacters(in: .whitespaces)
            } else {
                hostString = forwardedForHeader
            }
        }
        let hexParts = hostString.components(separatedBy: ":")
        if hexParts.count == 8 {
            return hexParts[0...3].joined(separator: ":")
        }
        return hostString
    }
}
