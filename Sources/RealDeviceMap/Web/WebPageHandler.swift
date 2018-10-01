//
//  IndexHandler.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 18.09.18.
//

import Foundation
import PerfectLib
import PerfectHTTP
import PerfectMustache
import PerfectSession

struct WebPageHandler: MustachePageHandler {
    
    private var page: WebServer.Page
    private var data: MustacheEvaluationContext.MapType
    
    public init(page: WebServer.Page = .home, data: MustacheEvaluationContext.MapType = MustacheEvaluationContext.MapType()) {
        self.page = page
        self.data = data
    }
    
    public func extendValuesForResponse(context contxt: MustacheWebEvaluationContext, collector: MustacheEvaluationOutputCollector) {
        
        contxt.extendValues(with: data)

        do {
            try contxt.requestCompleted(withCollector: collector)
        } catch {
            let response = contxt.webResponse
            response.status = .internalServerError
            response.appendBody(string: "\(error)")
            response.completed()
        }
    }
    
}

