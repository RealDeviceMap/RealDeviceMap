extension UInt8 {

    // Source: https://github.com/PerfectlySoft/Perfect-HTTP/blob/master/Sources/PerfectHTTP/StaticFileHandler.swift
    var hexString: String {
        let s = String(self, radix: 16)
        if s.count == 1 {
            return "0" + s
        }
        return s
    }

}