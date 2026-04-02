import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var viewModel: FloatingPanelViewModel

    var body: some View {
        HStack(spacing: 14) {
            HStack(alignment: .center, spacing: 4) {
                ForEach(Array(viewModel.barLevels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5, height: max(8, 32 * level))
                }
            }
            .frame(width: 44, height: 32, alignment: .center)

            Text(viewModel.displayText)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.25), value: viewModel.displayText)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .frame(width: viewModel.estimatedWidth())
    }
}
