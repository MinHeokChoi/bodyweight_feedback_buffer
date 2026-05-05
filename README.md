# 피드백 버퍼

맨몸운동 훈련 직후의 감각, 실수, 코칭 포인트를 기술별로 모아두고 다음 훈련 전에 다시 꺼내보는 iOS 앱입니다.

세트 수와 횟수처럼 숫자로 남기기 어려운 단서가 있습니다. Handstand에서 어깨가 말린 느낌, Pull ups에서 반동이 들어간 순간, Front Lever에서 코어가 풀린 감각처럼 금방 사라지는 피드백을 짧게 기록하고 우선순위대로 관리합니다.

## 주요 기능

- **피드백 버퍼**: 아직 해결하지 못한 피드백을 점수순으로 정렬해 오늘 먼저 볼 항목을 보여줍니다.
- **기술 라이브러리**: Handstand, HSPU, Pull ups, Front Lever 등 훈련 기술을 추가, 수정, 삭제, 정렬할 수 있습니다.
- **기술별 피드백 기록**: 각 기술에 대해 제목, 메모, 중요도, 훈련 범주를 기록합니다.
- **해결 / 더 연습 표시**: 반영된 피드백은 해결 처리하고, 다시 놓친 피드백은 더 연습으로 표시해 우선순위를 올립니다.
- **빠른 문구**: 자주 쓰는 피드백 문구를 직접 관리해 기록 시간을 줄입니다.
- **웜업 체크리스트**: 매일의 웜업 진행률을 확인하고 루틴을 직접 편집할 수 있습니다.
- **기기 내 저장**: 로그인, 서버 동기화, 분석 SDK 없이 사용자 기기 안에만 데이터를 저장합니다.

## 우선순위 계산

활성 피드백은 `FeedbackScoring`에서 한 번씩 점수를 계산한 뒤 내림차순으로 정렬합니다.

점수에는 아래 요소가 반영됩니다.

- 중요도
- 더 연습으로 표시된 횟수
- 생성 후 지난 시간
- 마지막 검토 후 지난 시간

점수 구간은 `critical`, `high`, `medium`, `low`로 나뉘며, 화면에서는 오래 방치되었거나 반복해서 놓친 피드백이 더 위로 올라오도록 설계되어 있습니다.

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
│   │   ├── Features
│   │   │   ├── Buffer
│   │   │   ├── Library
│   │   │   ├── Root
│   │   │   └── Warmup
│   │   ├── Models
│   │   ├── Services
│   │   └── State
│   └── Resources
├── FeedbackBufferTests
│   └── Sources
└── AppStoreSubmission_ko.md
```

### 주요 모듈

- `AppStore`: 앱 전역 상태와 사용자 액션을 관리하는 단일 상태 저장소입니다.
- `FeedbackRepository`: 피드백과 기술 목록을 JSON 파일로 저장하고 불러옵니다.
- `WarmupRepository`: 날짜별 웜업 체크 상태와 사용자 루틴을 `UserDefaults`에 저장합니다.
- `UserSettingsRepository`: 온보딩 완료 여부와 빠른 문구를 관리합니다.
- `FeedbackScoring`: 활성 피드백의 우선순위 점수를 계산합니다.
- `SampleData`: 첫 실행 시 사용할 기본 기술 목록을 제공합니다.

## 데이터 저장

앱은 별도 서버를 사용하지 않습니다.

- `feedbacks.json`: 사용자가 입력한 피드백 목록
- `skills.json`: 사용자가 관리하는 기술 목록
- `UserDefaults`: 온보딩 상태, 빠른 문구, 웜업 체크 상태, 웜업 루틴

저장 실패나 로드 실패가 발생하면 앱 내 알림으로 복구 메시지를 보여주고, 가능한 경우 기본 데이터로 앱을 계속 사용할 수 있게 처리합니다.

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

생성 후 `FeedbackBuffer.xcworkspace`를 Xcode에서 열어 실행합니다.

```bash
open FeedbackBuffer.xcworkspace
```

### 빌드

```bash
tuist build FeedbackBuffer
```

### 테스트

```bash
tuist test FeedbackBuffer
```

또는 Xcode에서 `FeedbackBufferTests` 타깃을 실행할 수 있습니다.

## 테스트 범위

현재 테스트는 핵심 도메인 동작을 중심으로 구성되어 있습니다.

- 피드백 점수 계산과 정렬
- 해결된 피드백 필터링
- 중요도, 방치 기간, 더 연습 횟수 반영
- 기본 기술 시딩
- 온보딩 상태 저장
- 빠른 문구 저장
- 피드백 추가, 해결, 삭제
- 웜업 체크와 날짜별 리셋
- 웜업 루틴 편집
- 기술 추가, 수정, 삭제, 정렬
- 기술명 변경 시 기존 피드백 동기화

## App Store 제출 메모

한국어 App Store Connect 제출용 초안은 `AppStoreSubmission_ko.md`에 정리되어 있습니다.

현재 앱은 다음 정책 방향을 기준으로 작성되어 있습니다.

- 로그인 없음
- 인앱 결제 없음
- 광고 없음
- 분석 SDK 없음
- 추적 없음
- 네트워크 통신 없음
- HealthKit, 위치, 카메라, 사진, 마이크 권한 사용 없음

`FeedbackBuffer/Resources/PrivacyInfo.xcprivacy`에는 수집 데이터 없음과 추적 없음이 반영되어 있습니다.

## 개발 원칙

이 프로젝트는 운동을 자동으로 분석하는 앱이 아니라, 사용자가 직접 느낀 훈련 단서를 잊지 않게 붙잡아두는 도구입니다. 그래서 기능은 기록의 마찰을 줄이고, 다음 훈련에서 같은 실수를 덜 반복하게 만드는 흐름에 집중합니다.

새 기능을 추가할 때는 아래 기준을 우선합니다.

- 기록까지 걸리는 탭 수를 늘리지 않을 것
- 피드백의 우선순위 판단을 흐리지 않을 것
- 사용자의 데이터를 외부로 보내지 않을 것
- 테스트 가능한 도메인 로직은 UI와 분리할 것
