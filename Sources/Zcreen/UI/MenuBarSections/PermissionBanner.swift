import SwiftUI

struct PermissionBanner: View {
    @Binding var accessibilityOK: Bool

    var body: some View {
        Button {
            AccessibilityHelper.openAccessibilitySettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                accessibilityOK = AccessibilityHelper.isTrusted
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Accessibility Permission Required")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Click to open System Settings")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.gradient)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
