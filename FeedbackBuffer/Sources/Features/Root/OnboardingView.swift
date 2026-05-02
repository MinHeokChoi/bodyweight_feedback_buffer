import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("피드백 버퍼")
                        .font(.largeTitle.weight(.bold))
                    Text("오늘 놓친 감각을 다음 훈련까지 선명하게 남겨두세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                onboardingPoint("target", title: "기술별로 모으기", body: "물구나무, 플란체, 풀업처럼 집중할 기술을 나눠 기록합니다.")
                onboardingPoint("bolt.heart", title: "우선순위 보기", body: "오래 방치되거나 반복되는 피드백을 먼저 보여줍니다.")
                onboardingPoint("checkmark.seal", title: "훈련 전 확인", body: "웜업을 마치고 오늘의 1순위를 바로 떠올립니다.")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onComplete) {
                Text("시작하기")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func onboardingPoint(_ systemImage: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView { }
}
