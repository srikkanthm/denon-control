import SwiftUI

struct VolumeSliderView: View {
    @Binding var value: Double
    let minValue: Double
    let maxValue: Double
    let step: Double
    var onValueChanged: (Double) -> Void

    @State private var isDragging = false

    private var range: Double { maxValue - minValue }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let centerY = geo.size.height / 2
            let fraction = min(max((value - minValue) / range, 0), 1)
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = 16
            let fillWidth = max(CGFloat(fraction) * width, trackHeight)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: width, height: trackHeight)
                    .position(x: width / 2, y: centerY)

                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(isDragging
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.95), Color(red: 0.6, green: 0.25, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )))
                    .frame(width: fillWidth, height: trackHeight)
                    .position(x: fillWidth / 2, y: centerY)

                ForEach(ticks(in: width), id: \.self) { x in
                    Rectangle()
                        .fill(Color.primary.opacity(0.14))
                        .frame(width: 1, height: 9)
                        .position(x: x, y: centerY)
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isDragging)
                    .position(x: thumbSize / 2 + CGFloat(fraction) * (width - thumbSize), y: centerY)
            }
            .frame(width: width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let frac = min(max(Double(g.location.x / width), 0), 1)
                        let raw = minValue + frac * range
                        let snapped = (raw / step).rounded() * step
                        let clamped = min(max(snapped, minValue), maxValue)
                        isDragging = true
                        value = clamped
                        onValueChanged(clamped)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 24)
        .accessibilityLabel("Volume")
        .accessibilityValue(Text(String(format: "%.1f", value)))
        .accessibilityRepresentation {
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        value = newValue
                        onValueChanged(newValue)
                    }
                ),
                in: minValue...maxValue,
                step: step
            )
        }
    }

    private func ticks(in width: CGFloat) -> [CGFloat] {
        var xs: [CGFloat] = []
        var tick = minValue
        while tick <= maxValue {
            let f = (tick - minValue) / range
            xs.append(CGFloat(f) * width)
            tick += 5
        }
        return xs
    }
}