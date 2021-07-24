// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RealDeviceMap",
    platforms: [
           .macOS(.v10_15)
    ],
    products: [],
    dependencies: [
        .package(name: "PerfectHTTPServer", url: "https://github.com/123FLO321/Perfect-HTTPServer.git", .branch("swift5")),
        .package(name: "PerfectSessionMySQL", url: "https://github.com/123FLO321/Perfect-Session-MySQL.git", .branch("swift5")),
        .package(name: "PerfectMySQL", url: "https://github.com/123FLO321/Perfect-MySQL.git", .branch("swift5")),
        .package(name: "PerfectThread", url: "https://github.com/123FLO321/Perfect-Thread.git", .branch("swift5")),
        .package(name: "PerfectMustache", url: "https://github.com/123FLO321/Perfect-Mustache.git", .branch("swift5")),
        .package(name: "PerfectCURL", url: "https://github.com/123FLO321/Perfect-CURL.git", .branch("swift5")),
        .package(name: "PerfectSMTP", url: "https://github.com/123FLO321/Perfect-SMTP.git", .branch("swift5")),
        .package(name: "PerfectCrypto", url: "https://github.com/123FLO321/Perfect-Crypto.git", .branch("swift5")),
        .package(name: "Turnstile", url: "https://github.com/123FLO321/Turnstile.git", from: "1.2.3"),
        .package(name: "Turf", url: "https://github.com/123FLO321/turf-swift.git", from: "0.5.0"),
        .package(name: "S2Geometry", url: "https://github.com/123FLO321/S2Geometry.git", from: "0.5.0"),
        .package(name: "Regex", url: "https://github.com/crossroadlabs/Regex.git", from: "1.2.0"),
        .package(name: "swift-backtrace", url: "https://github.com/swift-server/swift-backtrace.git", from: "1.2.0"),
        .package(name: "POGOProtos", url: "https://github.com/123FLO321/POGOProtos-Swift.git", .upToNextMinor(from: "2.3.1"))
    ],
    targets: [
        .target(
            name: "RealDeviceMap",
            dependencies: [
                .product(name: "PerfectHTTPServer", package: "PerfectHTTPServer"),
                .product(name: "PerfectSessionMySQL", package: "PerfectSessionMySQL"),
                .product(name: "PerfectMySQL", package: "PerfectMySQL"),
                .product(name: "PerfectThread", package: "PerfectThread"),
                .product(name: "PerfectMustache", package: "PerfectMustache"),
                .product(name: "PerfectCURL", package: "PerfectCURL"),
                .product(name: "PerfectSMTP", package: "PerfectSMTP"),
                .product(name: "PerfectCrypto", package: "PerfectCrypto"),
                .product(name: "Turnstile", package: "Turnstile"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "Turf", package: "Turf"),
                .product(name: "S2Geometry", package: "S2Geometry"),
                .product(name: "POGOProtos", package: "POGOProtos"),
                .product(name: "Backtrace", package: "swift-backtrace")
            ]
        ),
        .testTarget(
            name: "RealDeviceMapTests",
            dependencies: [
                "RealDeviceMap"
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
