import ProjectDescription

let project = Project(
    name: "FeedbackBuffer",
    organizationName: "julyheuk",
    options: .options(
        defaultKnownRegions: ["en", "ko"],
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
                "UILaunchScreen": [
                    "UIColorName": "LaunchBackground",
                    "UIImageName": "LaunchMark"
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait"
                ]
            ]),
            sources: ["FeedbackBuffer/Sources/**"],
            resources: ["FeedbackBuffer/Resources/**"]
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
