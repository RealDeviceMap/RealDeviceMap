//
//  WebHookEvent.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 03.10.18.
//

import Foundation

protocol WebHookEvent {
    func getWebhookValues() -> [String : Any]
}
