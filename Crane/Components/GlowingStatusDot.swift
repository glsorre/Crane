//
//  GlowingStatusDot.swift
//  Crane
//

import SwiftUI

struct GlowingStatusDot: View {
    let color: Color
    let isAnimated: Bool

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    init(color: Color, isAnimated: Bool = true) {
        self.color = color
        self.isAnimated = isAnimated
    }

    var body: some View {
        ZStack {
            if isAnimated {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .frame(width: 8, height: 8)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true)
                        ) {
                            pulseScale = 2.5
                            pulseOpacity = 0.0
                        }
                    }
            }

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.8), radius: 3)
        }
        .frame(width: 18, height: 18)
    }
}
