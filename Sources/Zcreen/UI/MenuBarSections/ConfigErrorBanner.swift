import SwiftUI

struct ConfigErrorBanner: View {
    let error: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Config Error")
                        .font(.system(size: 11, weight: .semibold))
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            MenuBarHelpers.sectionDivider
        }
    }
}
