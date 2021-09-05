extension UInt8 {

    // Source: https://github.com/PerfectlySoft/Perfect-HTTP/blob/master/Sources/PerfectHTTP/StaticFileHandler.swift
    var hexString: String {
        let string = String(self, radix: 16)
        if string.count == 1 {
            return "0" + string
        }
        return string
    }

}
