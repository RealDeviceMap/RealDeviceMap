import PerfectLib

extension File {
    // Source: https://github.com/PerfectlySoft/Perfect-HTTP/blob/master/Sources/PerfectHTTP/StaticFileHandler.swift
    var eTag: String {
        let eTagStr = path + "\(modificationTime)"
        let eTag = eTagStr.utf8.sha1
        let eTagReStr = eTag.map { $0.hexString }.joined(separator: "")
        return eTagReStr
    }
}
