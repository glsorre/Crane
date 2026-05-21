//
//  SparklineChartView.swift
//  Crane
//

import SwiftUI

struct SparklineChartView: View {
    let data: [Double]
    let maxBound: Double?
    let strokeColor: Color
    let fillGradient: LinearGradient

    init(
        data: [Double],
        maxBound: Double? = nil,
        strokeColor: Color = .accentColor,
        fillGradient: LinearGradient? = nil
    ) {
        self.data = data
        self.maxBound = maxBound
        self.strokeColor = strokeColor
        self.fillGradient = fillGradient ?? LinearGradient(
            colors: [strokeColor.opacity(0.25), strokeColor.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        GeometryReader { geometry in
            if data.count < 2 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Gathering metrics…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                let points = normalizedPoints(for: geometry.size)

                ZStack {
                    // Under-curve gradient fill
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        if let last = points.last {
                            path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        }
                        path.closeSubpath()
                    }
                    .fill(fillGradient)

                    // Line stroke
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                    }
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }

    private func normalizedPoints(for size: CGSize) -> [CGPoint] {
        guard !data.isEmpty else { return [] }
        
        let calculatedMax = data.max() ?? 1.0
        let maxVal = maxBound ?? max(calculatedMax, 1.0)
        let minVal = 0.0
        let deltaY = maxVal - minVal

        let stepX = size.width / CGFloat(max(data.count - 1, 1))

        return data.enumerated().map { index, val in
            let x = CGFloat(index) * stepX
            let normalizedY = deltaY > 0 ? (val - minVal) / deltaY : 0.5
            // Invert Y axis for SwiftUI coordinate system
            let y = size.height - CGFloat(normalizedY) * size.height
            // Clamp within visual frame to avoid clipping borders
            let clampedY = min(max(y, 1.5), size.height - 1.5)
            return CGPoint(x: x, y: clampedY)
        }
    }
}
