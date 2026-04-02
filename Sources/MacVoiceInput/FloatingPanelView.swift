import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var viewModel: FloatingPanelViewModel

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.15, blue: 0.2).opacity(0.96),
                            Color(red: 0.08, green: 0.09, blue: 0.13).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    statusBadgeColor.opacity(0.24),
                                    .clear,
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color.black.opacity(0.22), radius: 20, y: 12)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: meterColors,
                                center: .topLeading,
                                startRadius: 6,
                                endRadius: 28
                            )
                        )
                        .shadow(color: meterColors.first?.opacity(0.5) ?? .clear, radius: 16, y: 8)
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(Array(viewModel.barLevels.enumerated()), id: \.offset) { _, level in
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.98), Color.white.opacity(0.55)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 4, height: max(8, 28 * level))
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(width: 46, height: 46, alignment: .center)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(viewModel.titleText.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .tracking(1.1)

                        Text(viewModel.statusLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.96))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(statusBadgeColor.opacity(0.9))
                            )
                    }

                    Text(viewModel.secondaryText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.97))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.22), value: viewModel.secondaryText)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .clipShape(Capsule())
        .frame(height: 74)
        .frame(width: viewModel.estimatedWidth())
    }

    private var statusBadgeColor: Color {
        switch viewModel.status {
        case .listening:
            return Color(red: 0.95, green: 0.34, blue: 0.28)
        case .refining:
            return Color(red: 0.16, green: 0.67, blue: 0.96)
        case .message:
            return Color(red: 0.95, green: 0.67, blue: 0.18)
        }
    }

    private var meterColors: [Color] {
        switch viewModel.status {
        case .listening:
            return [Color(red: 1.0, green: 0.46, blue: 0.34), Color(red: 0.82, green: 0.16, blue: 0.22)]
        case .refining:
            return [Color(red: 0.34, green: 0.8, blue: 1.0), Color(red: 0.1, green: 0.43, blue: 0.95)]
        case .message:
            return [Color(red: 0.99, green: 0.82, blue: 0.36), Color(red: 0.93, green: 0.52, blue: 0.1)]
        }
    }
}
