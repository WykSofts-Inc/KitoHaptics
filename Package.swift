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
    targets: [
        .target(name: "KitoHaptics"),
        .testTarget(name: "KitoHapticsTests", dependencies: ["KitoHaptics"]),
    ]
)
