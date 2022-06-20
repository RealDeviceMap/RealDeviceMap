//
//  HTTPResponse.swift
//  RealDeviceMapLib
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

    func respondWithData(data: JSONConvertible,
                         drawCount: Int? = nil, recordsTotal: Int? = 0, recordsFiltered: Int? = 0) throws {
        if drawCount != nil {
            // draw is used in datatables
            do {
                try setBody(json: [
                    "draw": drawCount!, "recordsTotal": recordsTotal!, "recordsFiltered": recordsFiltered!,
                    "status": "ok", "data": data
                ])
            } catch {
                print("TMP error on setting body with pagination")
                print(data)
            }

        } else {
            do {
                try setBody(json: ["status": "ok", "data": data])
            } catch {
                print("TMP error on setting body without pagination")
                print(data)
            }

        }
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
