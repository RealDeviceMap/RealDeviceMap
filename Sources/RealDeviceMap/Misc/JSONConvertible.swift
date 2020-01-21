//
//  JSONConvertible.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 28.10.18.
//

import PerfectLib

extension JSONConvertible {

    func jsonEncodeForceTry() -> String? {

        do {
            let result = try self.jsonEncodedString()
            if result == "null" {
                return nil
            } else {
                return result
            }
        } catch {
            return nil
        }

    }

}
