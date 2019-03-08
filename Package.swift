// swift-tools-version:4.1

import PackageDescription

let package = Package(
    name: "RealDeviceMap",
    products: [],
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", from: "3.0.18"),
        .package(url: "https://github.com/123FLO321/Perfect-Session-MySQL.git", from: "3.1.6"),
        .package(url: "https://github.com/123FLO321/Perfect-MySQL.git", from: "3.2.2"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Thread.git", from: "3.0.5"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", from: "3.0.2"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-CURL.git", from: "3.0.7"),
        .package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", from: "3.3.0"),
        .package(url: "https://github.com/stormpath/Turnstile.git", from: "1.0.6"),
        .package(url: "https://github.com/crossroadlabs/Regex.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.2.0"),
        .package(url: "https://github.com/123FLO321/turf-swift.git", from: "0.3.1"),
        .package(url: "https://github.com/123FLO321/S2Geometry.git", from: "0.3.1"),
        .package(url: "https://github.com/123FLO321/POGOProtos-Swift.git", .upToNextMinor(from: "1.5.0")),
    ],
    targets: [
        .target(name: "RealDeviceMap", dependencies: ["PerfectHTTPServer","PerfectSessionMySQL","PerfectMySQL","PerfectThread","PerfectMustache","PerfectCURL","Turnstile","Regex","POGOProtos","Turf","S2Geometry", "PerfectSMTP"])
    ]
)
