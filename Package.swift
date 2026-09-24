// swift-tools-version: 5.9
//
//  Package.swift
//  KitoHaptics
//
//  Created by Wycliff on 6/9/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//


import PackageDescription

let package = Package(
    name: "KitoHaptics",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoHaptics", targets: ["KitoHaptics"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.1.0"),
    ],
    targets: [
        .target(name: "KitoHaptics", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoHapticsTests", dependencies: ["KitoHaptics"]),
    ]
)
