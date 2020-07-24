// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "RealDeviceMap",
    products: [],
    dependencies: [
        .package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", .upToNextMinor(from: "3.0.22")),
        .package(url: "https://github.com/123FLO321/Perfect-Session-MySQL.git", .upToNextMinor(from: "3.2.4")),
        .package(url: "https://github.com/123FLO321/Perfect-MySQL.git", .upToNextMinor(from: "3.2.2")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Thread.git", .upToNextMinor(from: "3.0.6")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Mustache.git", .upToNextMinor(from: "3.0.2")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-CURL.git", .upToNextMinor(from: "3.1.0")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-SMTP.git", .upToNextMinor(from: "3.3.0")),
        .package(url: "https://github.com/PerfectlySoft/Perfect-Crypto.git", .upToNextMinor(from: "3.2.0")),
        .package(url: "https://github.com/123FLO321/Turnstile.git", .upToNextMinor(from: "1.2.3")),
        .package(url: "https://github.com/crossroadlabs/Regex.git", .upToNextMinor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMinor(from: "1.9.0")),
        .package(url: "https://github.com/123FLO321/turf-swift.git", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/123FLO321/S2Geometry.git", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/123FLO321/POGOProtos-Swift.git", .upToNextMinor(from: "1.23.2"))
    ],
    targets: [
        .target(
            name: "RealDeviceMap",
            dependencies: [
                "PerfectHTTPServer",
                "PerfectSessionMySQL",
                "PerfectMySQL",
                "PerfectThread",
                "PerfectMustache",
                "PerfectCURL",
                "PerfectSMTP",
                "PerfectCrypto",
                "Turnstile",
                "Regex",
                "POGOProtos",
                "Turf",
                "S2Geometry"
            ]
        ),
        .testTarget(
            name: "RealDeviceMapTests",
            dependencies: [
                "RealDeviceMap"
            ]
        )
    ],
    swiftLanguageVersions: [.v4_2]
)
