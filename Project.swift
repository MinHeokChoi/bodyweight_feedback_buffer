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
                // tuist generate가 xcodeproj를 다시 만들 때마다 Xcode에서 고른
                // 개발팀이 지워져 기기 빌드가 깨졌다. 여기 박아 두면 재생성 후에도
                // 유지된다. 팀 ID는 배포된 앱 바이너리에 들어 있는 공개 값이고
                // 인증서 없이는 서명에 쓸 수 없다.
                base: ["DEVELOPMENT_TEAM": "Z7FSDLFCMK"],
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
            ],
            settings: .settings(
                base: ["DEVELOPMENT_TEAM": "Z7FSDLFCMK"]
            )
        )
    ],
    schemes: [
        .scheme(
            name: "FeedbackBuffer",
            shared: true,
            buildAction: .buildAction(targets: ["FeedbackBuffer"]),
            testAction: .targets([
                .testableTarget(target: "FeedbackBufferTests")
            ]),
            runAction: .runAction(configuration: .debug)
        )
    ]
)
