import SwiftUI

// MARK: - Design Tokens

enum DS {
    // MARK: Colours
    enum Color {
        static let accent        = SwiftUI.Color(red: 0.13, green: 0.76, blue: 0.37)
        static let accentDark    = SwiftUI.Color(red: 0.09, green: 0.51, blue: 0.27)
        static let accentMid     = SwiftUI.Color(red: 0.29, green: 0.87, blue: 0.50)
        static let accentHero    = SwiftUI.Color(red: 0.07, green: 0.50, blue: 0.24)  // dark hero card
        static let protein       = SwiftUI.Color(red: 0.23, green: 0.51, blue: 0.96)
        static let carbs         = SwiftUI.Color(red: 0.98, green: 0.45, blue: 0.09)
        static let fat           = SwiftUI.Color(red: 0.94, green: 0.27, blue: 0.27)
        static let coachPurple   = SwiftUI.Color(red: 0.49, green: 0.23, blue: 0.93)
        static let coachPurpleDk = SwiftUI.Color(red: 0.36, green: 0.16, blue: 0.75)
        static let surface       = SwiftUI.Color(.systemBackground)
        static let surfaceRaise  = SwiftUI.Color(.secondarySystemBackground)
        static let bgScreen      = SwiftUI.Color(red: 0.94, green: 0.99, blue: 0.96)  // #f0fdf4
    }

    // MARK: Radius
    enum Radius {
        static let xs: CGFloat  = 8
        static let sm: CGFloat  = 12
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 28
    }

    // MARK: Shadow
    enum Shadow {
        static let card   = ShadowConfig(color: .black.opacity(0.06), radius: 12, y: 4)
        static let lifted = ShadowConfig(color: .black.opacity(0.10), radius: 20, y: 7)
        static let float  = ShadowConfig(color: .black.opacity(0.13), radius: 28, y: 10)
        static let green  = ShadowConfig(color: SwiftUI.Color(red: 0.13, green: 0.76, blue: 0.37).opacity(0.35), radius: 20, y: 8)
    }

    // MARK: Animation
    enum Anim {
        static let spring     = Animation.spring(response: 0.45, dampingFraction: 0.72)
        static let springFast = Animation.spring(response: 0.32, dampingFraction: 0.75)
        static let smooth     = Animation.easeInOut(duration: 0.25)
        static let ring       = Animation.spring(response: 0.65, dampingFraction: 0.8)
        static let entrance   = Animation.spring(response: 0.5, dampingFraction: 0.78)
    }

    // MARK: Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentMid, Color.accentDark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 0.09, green: 0.64, blue: 0.30),
                SwiftUI.Color(red: 0.06, green: 0.44, blue: 0.21),
                SwiftUI.Color(red: 0.04, green: 0.35, blue: 0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var coachGradient: LinearGradient {
        LinearGradient(
            colors: [Color.coachPurple, Color.coachPurpleDk,
                     SwiftUI.Color(red: 0.29, green: 0.10, blue: 0.60)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ShadowConfig {
    let color: SwiftUI.Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    init(color: SwiftUI.Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        self.color = color; self.radius = radius; self.x = x; self.y = y
    }
}

// MARK: - Card Modifier

struct CardModifier: ViewModifier {
    var padding: EdgeInsets
    var shadow: ShadowConfig

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension View {
    func appCard(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        shadow: ShadowConfig = DS.Shadow.card
    ) -> some View {
        modifier(CardModifier(padding: padding, shadow: shadow))
    }

    func appCard(_ inset: CGFloat, shadow: ShadowConfig = DS.Shadow.card) -> some View {
        appCard(padding: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset), shadow: shadow)
    }
}

// MARK: - Entrance Animation

struct EntranceModifier: ViewModifier {
    var delay: Double
    var offset: CGFloat
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : offset)
            .onAppear {
                withAnimation(DS.Anim.entrance.delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func entranceAnimation(delay: Double = 0, offset: CGFloat = 18) -> some View {
        modifier(EntranceModifier(delay: delay, offset: offset))
    }
}

// MARK: - Haptics

enum Haptics {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select()   { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Green Button Style

struct GreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                DS.accentGradient
                    .opacity(configuration.isPressed ? 0.75 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DS.Anim.springFast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GreenButtonStyle {
    static var green: GreenButtonStyle { GreenButtonStyle() }
}

// MARK: - Pill Label

struct PillLabel: View {
    let text: String
    var color: Color = DS.Color.accent
    var size: Font = .caption2

    var body: some View {
        Text(text)
            .font(size.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Stat Cell

struct StatCell: View {
    let label: String
    let value: String
    var color: Color = .primary
    var subtext: String? = nil

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            if let sub = subtext {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Header

struct AppSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            trailing
        }
    }
}

extension AppSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { _ in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.45), location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .init(x: phase - 0.3, y: 0.5),
                        endPoint:   .init(x: phase + 0.3, y: 0.5)
                    )
                    .blendMode(.screen)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Fruit Pattern Background

struct FruitPatternBackground: View {
    var opacity: Double = 0.22

    var body: some View {
        Canvas { context, size in
            let green = GraphicsContext.Shading.color(
                Color(red: 0.13, green: 0.76, blue: 0.37).opacity(opacity)
            )
            let lw: CGFloat = 1.5
            let spacing: CGFloat = 90

            var row = 0
            var cy: CGFloat = 10
            while cy < size.height + spacing {
                var cx: CGFloat = row % 2 == 0 ? 10 : spacing / 2
                var col = 0
                while cx < size.width + spacing {
                    let idx = (row * 5 + col) % 7
                    var p = Path()
                    switch idx {
                    case 0: // Apple
                        p.addEllipse(in: CGRect(x: cx-13, y: cy-12, width: 26, height: 26))
                        p.move(to: CGPoint(x: cx, y: cy-12))
                        p.addLine(to: CGPoint(x: cx, y: cy-19))
                        p.move(to: CGPoint(x: cx, y: cy-17))
                        p.addQuadCurve(to: CGPoint(x: cx+9, y: cy-22),
                                       control: CGPoint(x: cx+5, y: cy-22))
                    case 1: // Orange
                        p.addEllipse(in: CGRect(x: cx-15, y: cy-15, width: 30, height: 30))
                        p.move(to: CGPoint(x: cx-11, y: cy-11))
                        p.addLine(to: CGPoint(x: cx+11, y: cy+11))
                        p.move(to: CGPoint(x: cx+11, y: cy-11))
                        p.addLine(to: CGPoint(x: cx-11, y: cy+11))
                        p.move(to: CGPoint(x: cx, y: cy-15))
                        p.addLine(to: CGPoint(x: cx, y: cy+15))
                        p.move(to: CGPoint(x: cx-15, y: cy))
                        p.addLine(to: CGPoint(x: cx+15, y: cy))
                    case 2: // Strawberry
                        p.addEllipse(in: CGRect(x: cx-11, y: cy-8, width: 22, height: 24))
                        p.move(to: CGPoint(x: cx-4, y: cy-8))
                        p.addLine(to: CGPoint(x: cx-8, y: cy-16))
                        p.move(to: CGPoint(x: cx, y: cy-8))
                        p.addLine(to: CGPoint(x: cx, y: cy-16))
                        p.move(to: CGPoint(x: cx+4, y: cy-8))
                        p.addLine(to: CGPoint(x: cx+8, y: cy-16))
                    case 3: // Grapes
                        for (ox, oy) in [(-8,-10),(8,-10),(0,-3),(-8,6),(8,6),(0,13)] {
                            p.addEllipse(in: CGRect(x: cx+CGFloat(ox)-7,
                                                    y: cy+CGFloat(oy)-7,
                                                    width: 14, height: 14))
                        }
                        p.move(to: CGPoint(x: cx, y: cy-17))
                        p.addLine(to: CGPoint(x: cx, y: cy-24))
                    case 4: // Watermelon slice
                        p.addArc(center: CGPoint(x: cx, y: cy+8),
                                 radius: 18,
                                 startAngle: .degrees(200),
                                 endAngle: .degrees(340),
                                 clockwise: false)
                        p.addLine(to: CGPoint(x: cx, y: cy+8))
                        p.closeSubpath()
                        p.move(to: CGPoint(x: cx-5, y: cy+4))
                        p.addLine(to: CGPoint(x: cx-5, y: cy+12))
                        p.move(to: CGPoint(x: cx+5, y: cy+4))
                        p.addLine(to: CGPoint(x: cx+5, y: cy+12))
                    case 5: // Lemon
                        p.addEllipse(in: CGRect(x: cx-16, y: cy-11, width: 32, height: 22))
                        p.move(to: CGPoint(x: cx-16, y: cy))
                        p.addLine(to: CGPoint(x: cx-22, y: cy-4))
                        p.move(to: CGPoint(x: cx+16, y: cy))
                        p.addLine(to: CGPoint(x: cx+22, y: cy-4))
                    default: // Cherry
                        p.addEllipse(in: CGRect(x: cx-14, y: cy-2, width: 12, height: 12))
                        p.addEllipse(in: CGRect(x: cx+2,  y: cy-4, width: 12, height: 12))
                        p.move(to: CGPoint(x: cx-8, y: cy-2))
                        p.addQuadCurve(to: CGPoint(x: cx+8, y: cy-4),
                                       control: CGPoint(x: cx, y: cy-16))
                    }
                    context.stroke(p, with: green, lineWidth: lw)
                    cx += spacing
                    col += 1
                }
                cy += spacing * 0.7
                row += 1
            }
        }
        .ignoresSafeArea()
    }
}

