// swift-tools-version:4.1

import PackageDescription

let package = Package(
    name: "RealDeviceMap",
    products: [],
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", .upToNextMinor(from: "3.0.22")),
        .package(url: "https://github.com/123FLO321/Perfect-Session-MySQL.git", .upToNextMinor(from: "3.2.3")),
        .package(url: "https://github.com/123FLO321/Perfect-MySQL.git", .upToNextMinor(from: "3.2.2")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Thread.git", .upToNextMinor(from: "3.0.6")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", .upToNextMinor(from: "3.0.2")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-CURL.git", .upToNextMinor(from: "3.1.0")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", .upToNextMinor(from: "3.3.0")),
        .package(url: "https://github.com/123FLO321/Turnstile.git", .upToNextMinor(from: "1.2.1")),
        .package(url: "https://github.com/crossroadlabs/Regex.git", .upToNextMinor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMinor(from: "1.5.0")),
        .package(url: "https://github.com/123FLO321/turf-swift.git", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/123FLO321/S2Geometry.git", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/123FLO321/POGOProtos-Swift.git", .upToNextMinor(from: "1.6.0")),
    ],
    targets: [
        .target(name: "RealDeviceMap", dependencies: ["PerfectHTTPServer","PerfectSessionMySQL","PerfectMySQL","PerfectThread","PerfectMustache","PerfectCURL","PerfectSMTP","Turnstile","Regex","POGOProtos","Turf","S2Geometry"])
    ],
    swiftLanguageVersions: [4]
)
