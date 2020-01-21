//
//  HTTPResponse.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import PerfectLib
import PerfectHTTP
import PerfectSession

extension HTTPResponse {

    public func respondWithError(status: HTTPResponseStatus) {
        _ = try? setBody(json: ["status": "error", "error": status.description])
        setHeader(.contentType, value: "application/json")
        completed(status: status)
    }

    public func respondWithData(data: JSONConvertible) throws {
        try setBody(json: ["status": "ok", "data": data])
        setHeader(.contentType, value: "application/json")
        completed()
    }

    public func respondWithOk() {
        do {
            try setBody(json: ["status": "ok"])
        } catch {
            return completed(status: .internalServerError)
        }
        setHeader(.contentType, value: "application/json")
        completed()
    }

    public func redirect(path: String) {
        self.status = .found
        self.setHeader(.location, value: path)
    }

}
