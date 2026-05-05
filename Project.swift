import ProjectDescription

let project = Project(
    name: "FeedbackBuffer",
    organizationName: "julyheuk",
    options: .options(
        defaultKnownRegions: ["ko"],
        developmentRegion: "ko"
    ),
    targets: [
        .target(
            name: "FeedbackBuffer",
            destinations: .iOS,
            product: .app,
            bundleId: "com.julyheuk.feedbackbuffer",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "피드백 버퍼",
                "ITSAppUsesNonExemptEncryption": false,
                "UIRequiredDeviceCapabilities": ["arm64"],
                "UILaunchScreen": [
                    "UIColorName": "LaunchBackground",
                    "UIImageName": "LaunchMark"
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait"
                ]
            ]),
            sources: ["FeedbackBuffer/Sources/**"],
            resources: ["FeedbackBuffer/Resources/**"],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", settings: [
                        "CODE_SIGN_IDENTITY": "Apple Development",
                        "CODE_SIGN_STYLE": "Automatic"
                    ]),
                    .release(name: "Release", settings: [
                        "CODE_SIGN_IDENTITY": "Apple Distribution",
                        "CODE_SIGN_STYLE": "Automatic"
                    ])
                ]
            )
        ),
        .target(
            name: "FeedbackBufferTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.julyheuk.feedbackbuffer.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["FeedbackBufferTests/Sources/**"],
            dependencies: [
                .target(name: "FeedbackBuffer")
            ]
        )
    ]
)
