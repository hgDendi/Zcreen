import SwiftUI

struct ConfigErrorBanner: View {
    let issue: ConfigIssue
    let onOpenConfig: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Config Error")
                        .font(.system(size: 11, weight: .semibold))
                    Text(issue.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button("Open") {
                    onOpenConfig()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 4) {
                if let fieldPath = issue.fieldPath {
                    infoRow(label: "Field", value: fieldPath, monospaced: true)
                }
                infoRow(label: "Fix", value: issue.suggestion, monospaced: false)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            MenuBarHelpers.sectionDivider
        }
    }

    private func infoRow(label: String, value: String, monospaced: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            Text(value)
                .font(monospaced ? .system(size: 10, design: .monospaced) : .system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
