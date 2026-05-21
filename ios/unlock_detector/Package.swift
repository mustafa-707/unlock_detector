// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "unlock_detector",
  platforms: [
    .iOS("13.0"),
  ],
  products: [
    .library(name: "unlock-detector", targets: ["unlock_detector"]),
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
  ],
  targets: [
    .target(
      name: "unlock_detector",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy"),
      ]
    ),
  ]
)
