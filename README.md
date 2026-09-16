# 피드백 버퍼 Feedback Buffer

> 맨몸운동 직후 사라지는 감각과 코칭 포인트를 붙잡아, 다음 훈련에서 다시 꺼내보는 iOS 앱

![iOS](https://img.shields.io/badge/iOS-17.0%2B-black)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)
![Tuist](https://img.shields.io/badge/Project-Tuist-blue)
![Privacy](https://img.shields.io/badge/Privacy-On--device-green)

## 소개

**피드백 버퍼**는 맨몸운동을 하며 느낀 미세한 감각, 실수, 코칭 포인트를 기술별로 기록하고 다음 훈련 전에 다시 확인할 수 있게 도와주는 개인 훈련 피드백 앱입니다.

운동 기록 앱은 보통 세트 수, 횟수, 무게처럼 숫자로 남기기 쉬운 정보를 기록합니다.  
하지만 맨몸운동에서 정말 중요한 단서는 숫자가 아닐 때가 많습니다.

- Handstand에서 어깨가 말린 느낌
- HSPU 라인이 무너진 순간
- Pull ups에서 반동이 들어간 타이밍
- Front Lever에서 코어가 풀린 감각
- Dips에서 어깨가 불안정했던 구간

이런 피드백은 운동 직후에는 선명하지만, 시간이 지나면 금방 흐려집니다.  
피드백 버퍼는 그 짧은 감각을 빠르게 기록하고, 중요도와 반복 여부에 따라 다시 볼 순서를 정리해줍니다.

## 문제의식

맨몸운동 실력은 단순히 “몇 회 했는가”만으로 늘지 않습니다.

같은 동작을 반복하더라도  
어떤 라인이 무너졌는지,  
어떤 감각을 다시 찾아야 하는지,  
어떤 실수를 반복하고 있는지를 알아야 다음 훈련이 달라집니다.

피드백 버퍼는 운동을 대신 분석해주는 앱이 아닙니다.  
사용자가 직접 느낀 훈련 단서를 잊지 않도록 붙잡아두는 도구입니다.

## 주요 기능

### 1. 피드백 버퍼

아직 해결하지 못한 피드백을 우선순위대로 보여줍니다.

중요도가 높거나, 오래 방치되었거나, 반복해서 놓친 피드백일수록 더 위에 표시되어 오늘 먼저 확인해야 할 포인트를 빠르게 찾을 수 있습니다.

### 2. 기술별 피드백 기록

각 기술마다 다른 피드백을 분리해서 관리할 수 있습니다.

예시 기술:

- Handstand
- HSPU
- Pull ups
- Front Lever
- Dips
- Muscle Up

각 피드백에는 제목, 메모, 중요도, 상태를 기록할 수 있습니다.

### 3. 해결 / 더 연습 표시

훈련에서 반영한 피드백은 **해결** 처리할 수 있습니다.  
다시 놓친 피드백은 **더 연습**으로 표시해 우선순위를 올릴 수 있습니다.

이를 통해 단순한 메모장이 아니라, 반복되는 약점을 다시 끌어올리는 피드백 루프를 만들 수 있습니다.

### 4. 빠른 문구

자주 쓰는 피드백 문구를 직접 관리할 수 있습니다.

예를 들어:

- 코어 풀림
- 어깨 말림
- 손목 눌림
- 라인 무너짐
- 반동 들어감

반복해서 쓰는 표현을 빠르게 입력할 수 있어 운동 직후 기록 부담을 줄입니다.

### 5. 기술 라이브러리

자신이 훈련하는 기술을 직접 추가, 수정, 삭제, 정렬할 수 있습니다.

기술 이름을 변경하면 기존 피드백의 기술명도 함께 동기화되도록 설계했습니다.

### 6. 운동 타이머

운동 시간을 앱 안에서 재고 기록으로 남깁니다.

구간(웜업 / 기술 연습 / 스트렝스 / 피로저항 / 스트레칭 / 러닝)을 누르면 전체 누적 타이머와 구간 타이머가 함께 시작됩니다. 구간을 끝내고 다음 구간을 시작하기 전까지는 휴식으로 자동 측정되며, 따로 누를 버튼이 없습니다.

스트렝스 구간에서는 9분(3분 × 3세트 = 한 운동) 단위로 다음 운동으로 저절로 넘어갑니다. 넘어가도 구간 누적 시간은 줄지 않습니다.

경과 시간은 틱을 누적하지 않고 시작 시각으로부터 매번 계산합니다. 화면이 꺼져 있어도, 앱이 강제 종료돼도, 기기를 재부팅해도 시간이 어긋나지 않습니다.

### 7. 훈련 통계

어떤 운동에 얼마나 시간을 쓰고 있는지와 어느 날에 운동을 갔는지를 봅니다.

- 구간별 시간 배분과 비율
- 주 단위 추이
- 운동한 날 캘린더
- 연속 운동 일수

"총 운동 시간"은 구간 시간의 합이며 휴식은 빼고 따로 표기합니다.

### 8. 웜업 체크리스트

매일 확인하는 웜업 루틴을 관리할 수 있습니다. 루틴은 여러 개 만들어 두고 전환할 수 있습니다.

시작을 누르면 항목을 한 장씩 넘기며 따라갈 수 있고, 건너뛴 항목이 있어도 끝까지 진행했다면 그날 웜업은 완료로 봅니다. 완료 표시는 진행률을 100%로 부풀리지 않고 "2개 완료 · 7개 건너뜀"처럼 실제 숫자를 함께 적습니다.

### 9. 시즌 측정 기록

시즌 막바지에 재는 1RM이나 기술 수행력을 모아 둡니다. 기술 라이브러리 탭 왼쪽 위 자 모양 버튼으로 들어갑니다.

측정 종목은 **카테고리 · 세부 동작 · 제약 · 단위 · 방향**으로 정의하고 시즌마다 재사용합니다.

- **방향**을 저장합니다. "3분을 몇 번의 시도 안에 채우는지"처럼 값이 작을수록 잘한 종목이 있어서, 방향이 없으면 개선을 후퇴로 표시하게 됩니다.
- **제약은 종목에 적고 기록에 복사**합니다. 나중에 제약을 고치면 조건이 달랐던 과거 기록에 "이때는 제약이 달랐어요"가 붙습니다. 조건이 조용히 바뀌면 시즌 간 비교가 거짓이 되기 때문입니다.
- 시즌 이름은 시작일에서 "2026 가을"처럼 자동으로 붙고, 언제든 고칠 수 있습니다.
- 한 시즌에 여러 번 쟀다면 방향을 적용한 가장 잘한 값이 그 시즌의 대표값입니다.

### 10. 기기 내 저장

피드백 버퍼는 별도 서버를 사용하지 않습니다.

- 로그인 없음
- 광고 없음
- 분석 SDK 없음
- 추적 없음
- 네트워크 통신 없음

사용자가 입력한 피드백, 기술, 빠른 문구, 웜업, 운동 기록, 측정 기록은 기기 안에 저장됩니다.

## 피드백 우선순위 계산

활성 피드백은 `FeedbackScoring`을 통해 점수를 계산한 뒤 내림차순으로 정렬됩니다.

점수에는 다음 요소가 반영됩니다.

| 요소 | 의미 |
| --- | --- |
| 중요도 | 사용자가 직접 지정한 피드백의 중요도 |
| 더 연습 횟수 | 다시 놓친 횟수 |
| 생성 후 지난 시간 | 오래된 피드백이 묻히지 않도록 반영 |
| 마지막 검토 후 지난 시간 | 오랫동안 다시 보지 않은 피드백을 끌어올림 |

점수 구간은 다음과 같이 나뉩니다.

| Tier | 의미 |
| --- | --- |
| `critical` | 가장 먼저 확인해야 하는 피드백 |
| `high` | 우선순위가 높은 피드백 |
| `medium` | 꾸준히 확인할 피드백 |
| `low` | 상대적으로 낮은 우선순위의 피드백 |

## 기술 스택

- Swift
- SwiftUI
- Observation
- XCTest
- Tuist
- iOS 17.0+

## 프로젝트 구조

```text
.
├── Project.swift
├── Tuist.swift
├── FeedbackBuffer
│   ├── Sources
│   │   ├── App
│   │   ├── DesignSystem
│   │   ├── Features
│   │   │   ├── Buffer
│   │   │   ├── Library
│   │   │   ├── Root
│   │   │   ├── Timer
│   │   │   └── Warmup
│   │   ├── Models
│   │   ├── Services
│   │   └── State
│   └── Resources
├── FeedbackBufferTests
│   └── Sources
└── AppStoreSubmission_ko.md
```

## 주요 설계

### AppContainer

앱 시작 시 공통 의존성을 만들고 기능 Store를 연결하는 Composition Root입니다. 기능 상태나 사용자 액션을 직접 관리하지 않습니다.

### AppSessionStore

온보딩 완료 여부와 전역 저장 오류 알림을 관리합니다.

### FeedbackStore

피드백, 기술, 빠른 문구와 피드백 우선순위 파생값을 관리합니다. 피드백 추가·편집·보관·삭제, 기술 관리, 기본 기술 시딩과 스키마 마이그레이션을 담당합니다.

### WarmupStore

웜업 세션, 루틴, 일별 체크 상태와 진행률을 관리합니다. 세션 전환, 루틴 편집, 날짜 변경 시 상태 갱신을 담당합니다.

### WorkoutTimerStore

진행 중인 운동 세션과 사용자 액션을 관리합니다. 이 Store는 타이머를 돌리지 않습니다. 시간 계산은 전부 `WorkoutClock`이 맡고 화면 갱신은 View가 하므로, 탭을 벗어나도 상태가 흐트러지지 않습니다.

각 SwiftUI 화면은 필요한 Store만 `Environment`로 주입받습니다. Buffer와 Library는 `FeedbackStore`, Warmup은 `WarmupStore`, Timer는 `WorkoutTimerStore`, Root는 `AppSessionStore`에 의존합니다.

### FeedbackRepository

피드백과 기술 목록을 JSON 파일로 저장하고 불러옵니다.

- `feedbacks.json`
- `skills.json`

### WarmupRepository

날짜별 웜업 체크 상태와 사용자 루틴을 `UserDefaults`에 저장합니다.

### UserSettingsRepository

온보딩 완료 여부와 빠른 문구를 관리합니다.

### FeedbackScoring

활성 피드백의 우선순위 점수를 계산하고 정렬합니다.

### WorkoutRepository

완료된 세션(`workoutSessions.json`)과 진행 중 세션(`workoutActiveSession.json`)을 나눠 저장합니다. 진행 중 세션은 구간 전환·랩·일시정지마다 즉시 저장되어야 하므로 파일을 분리했습니다.

### WorkoutClock

세션 시간 계산을 담당하는 순수 로직입니다. 틱을 누적하지 않고 저장된 시각으로부터 매번 다시 계산합니다. 휴식은 저장하지 않고 `순수 시간 − 구간 시간 합`으로 구합니다.

### WorkoutStatistics

기간별 운동 집계를 계산하는 순수 로직입니다.

### WorkoutSessionEditor

기록을 길이만으로 다시 짜는 순수 로직입니다. 수동 기록을 만들고, 기존 기록의 구간 길이를 바꿉니다. 길이를 바꾸면 뒤 구간이 통째로 밀리고 구간 사이 간격은 유지됩니다.

### MeasurementStore / MeasurementProgress

측정 종목·시즌·기록을 들고 있는 스토어와, 그것을 시즌 단위로 접어 비교 가능한 모습으로 만드는 순수 로직입니다. 방향 적용과 제약 변경 감지가 여기 있습니다.

### DS (디자인 토큰)

색, radius, 여백, 타이포를 한 곳에 모읍니다. 구간 구분색은 앱 아이콘의 코랄·민트·크림에서 파생했습니다.

### SampleData

첫 실행 시 사용할 기본 기술 목록을 제공합니다.

## 데이터 저장 방식

앱은 서버 없이 동작합니다.

| 데이터 | 저장 위치 |
| --- | --- |
| 피드백 목록 | `feedbacks.json` |
| 기술 목록 | `skills.json` |
| 온보딩 상태 | `UserDefaults` |
| 빠른 문구 | `UserDefaults` |
| 웜업 체크 상태 | `UserDefaults` |
| 웜업 루틴 | `UserDefaults` |
| 운동 기록 | `workoutSessions.json` |
| 진행 중인 운동 | `workoutActiveSession.json` |
| 측정 종목 | `measurementItems.json` |
| 시즌 | `measurementSeasons.json` |
| 측정 기록 | `measurementRecords.json` |
| 웜업 완료 여부 | `UserDefaults` |

저장 또는 로드 실패가 발생하면 앱 내 알림으로 복구 메시지를 보여주고, 가능한 경우 기본 데이터로 앱을 계속 사용할 수 있도록 처리합니다.

## 실행 방법

### 요구 사항

- macOS
- Xcode
- Tuist
- iOS 17.0 이상 시뮬레이터 또는 실제 기기

### 프로젝트 생성

```bash
tuist generate
```

생성 후 Xcode에서 워크스페이스를 엽니다.

```bash
open FeedbackBuffer.xcworkspace
```

### 빌드

```bash
tuist xcodebuild build \
  -workspace FeedbackBuffer.xcworkspace \
  -scheme FeedbackBuffer \
  -destination 'generic/platform=iOS Simulator'
```

### 실제 기기에 설치

기기를 연결하고 개발자 모드를 켠 뒤 실행합니다.

```bash
xcodebuild build \
  -workspace FeedbackBuffer.xcworkspace \
  -scheme FeedbackBuffer \
  -destination 'platform=iOS,id=<기기 UDID>' \
  -allowProvisioningUpdates
```

연결된 기기의 UDID는 `xcrun devicectl list devices`로 확인합니다.

개발팀은 `Project.swift`에 지정돼 있어 `tuist generate`로 프로젝트를 다시 만들어도 유지됩니다. 다른 계정으로 빌드하려면 그 값을 바꿉니다.

### 테스트

```bash
tuist xcodebuild test \
  -workspace FeedbackBuffer.xcworkspace \
  -scheme FeedbackBuffer \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

설치된 시뮬레이터 이름이 다르면 `iPhone 16`을 해당 이름으로 바꿉니다. 또는 Xcode에서 `FeedbackBuffer` Scheme의 Test Action을 실행할 수 있습니다.

## 테스트 범위

현재 테스트는 핵심 도메인 로직을 중심으로 구성되어 있습니다.

- 피드백 점수 계산
- 피드백 우선순위 정렬
- 해결된 피드백 필터링
- 중요도, 방치 기간, 더 연습 횟수 반영
- 기본 기술 시딩
- 온보딩 상태 저장
- 빠른 문구 저장
- 피드백 추가, 해결, 삭제
- 웜업 체크와 날짜별 리셋
- 웜업 루틴 편집
- 기술 추가, 수정, 삭제, 정렬
- 세션 시간 계산과 일시정지 제외
- 백그라운드 복귀 시 지나간 랩 소급 반영
- 랩 리셋이 구간 누적을 줄이지 않는지
- 휴식 파생 계산
- 진행 중 세션 복구와 종료 처리
- 기간별 통계 집계와 연속 일수
- 기술명 변경 시 기존 피드백 동기화
- 중복 기술명 방지
- 저장 실패 시 복구 흐름
- AppContainer의 온보딩·전역 오류 연결

## App Store 제출 메모

한국어 App Store Connect 제출용 초안은 `AppStoreSubmission_ko.md`에 정리되어 있습니다.

현재 앱은 다음 방향을 기준으로 작성되어 있습니다.

- 로그인 없음
- 인앱 결제 없음
- 광고 없음
- 분석 SDK 없음
- 추적 없음
- 네트워크 통신 없음
- HealthKit, 위치, 카메라, 사진, 마이크 권한 사용 없음

`FeedbackBuffer/Resources/PrivacyInfo.xcprivacy`에는 수집 데이터 없음과 추적 없음이 반영되어 있습니다.

## 개발 원칙

이 프로젝트의 핵심은 “운동을 자동으로 분석하는 것”이 아니라,  
사용자가 직접 느낀 훈련 단서를 잊지 않게 붙잡아두는 것입니다.

새 기능을 추가할 때는 아래 기준을 우선합니다.

- 기록까지 걸리는 탭 수를 늘리지 않을 것
- 피드백의 우선순위 판단을 흐리지 않을 것
- 사용자의 데이터를 외부로 보내지 않을 것
- 테스트 가능한 도메인 로직은 UI와 분리할 것

## 향후 개선 아이디어

- 피드백 검색 및 필터
- 기술별 투자 시간 통계
- 주간 훈련 회고
- 잠금화면 Live Activity
- 운동 중 화면 꺼짐 방지 옵션
- iCloud 동기화 옵션
- 스크린샷 기반 App Store 소개 이미지 추가

## 한 줄 요약

**피드백 버퍼는 맨몸운동 직후의 감각을 잊지 않고, 다음 훈련에서 다시 꺼내보게 만드는 개인 피드백 루프 앱입니다.**
