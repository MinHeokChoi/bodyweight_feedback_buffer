import SwiftUI

/// 앱 전체가 공유하는 디자인 토큰.
///
/// 지금까지 radius가 22, 16, 14, 10으로 흩어져 있고 여백도 화면마다 제각각이었다.
/// 새 화면이 다섯 번째 radius를 추가하지 않도록 이 파일 한 곳에만 정의한다.
///
/// 문법은 타이머 탭 목업에서 가져왔고(radius 12, 높은 밀도, 작은 라벨 위계),
/// 재료는 기존 앱 것을 쓴다(코랄 accent, SF Symbols, Dynamic Type).
/// 자세한 배경은 `docs/TIMER_TAB_REQUIREMENTS.md` 9절 참고.
enum DS {

    // MARK: - Radius

    enum Radius {
        /// 카드, 버튼, 지표 타일 공통
        static let card: CGFloat = 12
        /// 카드 안에 들어가는 작은 요소
        static let inner: CGFloat = 8
        /// 진행 바 등 얇은 막대
        static let bar: CGFloat = 3
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Hairline

    enum Line {
        static let width: CGFloat = 0.5
        /// 기존 앱이 쓰던 것과 같은 값이다. 목업의 0.5px hairline과도 일치한다.
        static var color: Color { Color(.separator).opacity(0.35) }
    }

    // MARK: - Typography

    enum Typo {
        /// 타이머 숫자. 동적으로 커지면 레이아웃이 깨지므로 타이머 숫자만 고정 크기를 허용한다.
        static let timer = Font.system(size: 46, weight: .bold, design: .rounded).monospacedDigit()
        /// 구간 진행 중의 큰 숫자. 폰을 바닥에 두고 1~2m 떨어져 본다.
        /// 46pt는 실제 글자 높이가 6mm쯤이라 그 거리에서 읽기 어려웠다.
        /// 한 시간을 넘으면 자리가 모자라니 쓰는 곳에서 minimumScaleFactor를 건다.
        static let timerHero = Font.system(size: 96, weight: .bold, design: .rounded).monospacedDigit()
        /// 보조 타이머(누적 등). 살아 움직이는 숫자라 자리 흔들림을 막아야 해서 고정.
        static let timerSmall = Font.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()

        /// 통계·요약의 값. 흐르는 숫자가 아니므로 Dynamic Type을 따른다.
        static let metricValue = Font.title3.weight(.semibold).monospacedDigit()

        /// 아래는 전부 Dynamic Type을 유지한다.
        static let screenTitle = Font.title3.weight(.semibold)
        static let sectionLabel = Font.caption
        static let metaLabel = Font.footnote
        static let value = Font.subheadline.weight(.semibold)
        static let buttonLabel = Font.subheadline.weight(.semibold)
        /// 목록·통계의 숫자. 자리 흔들림만 막는다.
        static let number = Font.subheadline.weight(.semibold).monospacedDigit()
    }

    // MARK: - Surfaces

    enum Surface {
        /// 화면 바탕
        static var page: Color { Color(.systemGroupedBackground) }
        /// 카드
        static var card: Color { Color(.secondarySystemGroupedBackground) }
        /// 테두리 없이 배경 tint만 쓰는 지표 타일
        static var tile: Color { Color(.tertiarySystemFill) }
    }

    // MARK: - Tint

    enum Tint {
        /// accent 코랄을 글자로 쓸 때.
        ///
        /// 채움색 #FF6B4A는 흰 바탕이나 회색 바탕 위 글자로 약 2.2~2.8:1밖에 안 된다.
        /// 채움색은 그대로 두고(D19) 라이트 모드 글자만 명도를 낮춘다. 흰 바탕에서 약 4.8:1이다.
        /// 다크 모드는 원래 색으로도 충분히 읽힌다.
        static let accentText = Color(light: 0xC8452A, dark: 0xFF8A66)
    }

    // MARK: - Segment palette

    /// 구간 구분색. 앱 아이콘의 코랄(#FF7E44)·민트(#70DBB8)·크림(#F7F1EA)에서 파생했다.
    ///
    /// 새 색을 발명하지 않은 이유는 아이콘과 앱이 같은 색을 쓰게 하기 위해서다.
    /// 처음에는 피드백 우선순위 등급이 red/orange/yellow를 써서 그 세 색을 피했다.
    /// 등급은 없어졌지만 경고·묵은 표시가 여전히 주황을 쓰므로 그대로 둔다.
    enum Segment {
        /// 스트레칭 — 크림에서 파생한 모래색
        static let stretching = Color(light: 0xBFA07A, dark: 0xD9BD9A)
        /// 웜업 — 밝은 코랄
        static let warmup = Color(light: 0xFF9F6B, dark: 0xFFB68C)
        /// 기술 연습 — 민트. 피드백의 `기술 훈련` 범주와 짝이 된다
        static let skillPractice = Color(light: 0x2FA98A, dark: 0x70DBB8)
        /// 스트렝스 — accent 코랄 그대로
        static let strength = Color(light: 0xFF6B4A, dark: 0xFF8A66)
        /// 피로저항 — 깊은 코랄
        static let fatigueResistance = Color(light: 0xB84A2B, dark: 0xE0704C)
        /// 러닝 — 코랄 계열 밖의 청색. 유일한 유산소라 한눈에 구분되게 둔다
        static let running = Color(light: 0x3D7EA6, dark: 0x6FB2D9)
        /// 휴식 — 구간이 아니므로 중립색
        static var rest: Color { Color(.systemGray3) }
    }
}

// MARK: - Color helpers

extension Color {
    /// 라이트·다크 모드에서 각각 다른 16진 값을 쓰는 색.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
