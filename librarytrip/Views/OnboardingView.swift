import SwiftUI

struct OnboardingView: View {
    @AppStorage("username") private var username = ""
    @State private var nameInput = ""

    var body: some View {
        ZStack {
            Color.toshoCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.toshoGreen.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.toshoGreen)
                    }

                    VStack(spacing: 8) {
                        Text("librarytrip へようこそ")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.toshoText)
                        Text("図書館をめぐり、本と出会う旅をはじめよう")
                            .font(.system(size: 14))
                            .foregroundColor(.toshoSubtext)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("あなたのお名前を教えてください")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.toshoText)

                    HStack(spacing: 10) {
                        TextField("例: ゆきこ", text: $nameInput)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color.toshoCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.toshoGreen.opacity(nameInput.isEmpty ? 0.2 : 0.6), lineWidth: 1.5)
                            )
                    }

                    Text("マイページに表示されます。あとから変更はできません")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 32)

                Button {
                    let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    username = trimmed
                } label: {
                    Text("はじめる")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(nameInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.35) : Color.toshoGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 28)

                Spacer().frame(height: 48)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
