//
//  MySQLStmt.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectMySQL

extension MySQLStmt {
    
    func bindParam(_ i: UInt64?) {
        if (i == nil) {
            bindParam()
        } else {
            bindParam(i!)
        }
    }
    
    func bindParam(_ i: UInt32?) {
        if (i == nil) {
            bindParam()
        } else {
            bindParam(i!)
        }
    }
    
    func bindParam(_ i: UInt16?) {
        if (i == nil) {
            bindParam()
        } else {
            bindParam(i!)
        }
    }
    
    func bindParam(_ i: UInt8?) {
        if (i == nil) {
            bindParam()
        } else {
            bindParam(i!)
        }
    }
    
    func bindParam(_ d: Double?) {
        if (d == nil) {
            bindParam()
        } else {
            bindParam(d!)
        }
    }
    
    func bindParam(_ s: String?) {
        if (s == nil) {
            bindParam()
        } else {
            bindParam(s!)
        }
    }
    
    func bindParam(_ b: Bool?) {
        if (b == nil) {
            bindParam()
        } else if b == true {
            bindParam(1)
        } else {
            bindParam(0)
        }
    }
}
