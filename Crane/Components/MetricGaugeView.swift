//
//  MetricGaugeView.swift
//  Crane
//

import SwiftUI

struct MetricGaugeView: View {
    let title: String
    let value: Double // Range 0.0 to 1.0
    let displayString: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                // Dim track background
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 5.5)

                // Colored progress arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(max(value, 0.0), 1.0)))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: value)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(displayString)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor).opacity(0.4))
        )
    }
}
