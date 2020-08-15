//
//  MySQLStmt.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectMySQL
import PerfectLib
import Foundation

extension MySQLStmt {

    func bindParam(_ value: UInt64?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: UInt32?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: UInt16?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: UInt8?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: Double?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: String?) {
        if value == nil {
            bindParam()
        } else {
            bindParam(value!)
        }
    }

    func bindParam(_ value: Bool?) {
        if value == nil {
            bindParam()
        } else if value == true {
            bindParam(1)
        } else {
            bindParam(0)
        }
    }

}
