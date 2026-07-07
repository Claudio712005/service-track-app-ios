// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ServiceTrackKit",
    defaultLocalization: "pt-BR",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "STDomain", targets: ["STDomain"]),
        .library(name: "STCore", targets: ["STCore"]),
        .library(name: "STNetworking", targets: ["STNetworking"]),
        .library(name: "STPersistence", targets: ["STPersistence"]),
        .library(name: "STData", targets: ["STData"]),
        .library(name: "STFeatureAuth", targets: ["STFeatureAuth"]),
        .library(name: "STFeaturePerfil", targets: ["STFeaturePerfil"]),
        .library(name: "STFeatureDashboard", targets: ["STFeatureDashboard"]),
    ],
    targets: [
        .target(name: "STDomain"),
        .target(name: "STCore", dependencies: ["STDomain"]),
        .target(name: "STNetworking", dependencies: ["STDomain"]),
        .target(name: "STPersistence", dependencies: ["STDomain"]),
        .target(name: "STData", dependencies: ["STDomain", "STNetworking"]),
        .target(name: "STFeatureAuth", dependencies: ["STDomain", "STCore"]),
        .target(name: "STFeaturePerfil", dependencies: ["STDomain", "STCore"]),
        .target(name: "STFeatureDashboard", dependencies: ["STDomain", "STCore"]),
        .testTarget(name: "STDomainTests", dependencies: ["STDomain"]),
        .testTarget(name: "STNetworkingTests", dependencies: ["STNetworking"]),
        .testTarget(name: "STDataTests", dependencies: ["STData"]),
        .testTarget(name: "STFeatureAuthTests", dependencies: ["STFeatureAuth"]),
        .testTarget(name: "STFeaturePerfilTests", dependencies: ["STFeaturePerfil"]),
        .testTarget(name: "STFeatureDashboardTests", dependencies: ["STFeatureDashboard"]),
    ]
)
