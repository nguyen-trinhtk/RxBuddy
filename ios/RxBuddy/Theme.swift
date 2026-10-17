import SwiftUI
import CoreText

// Design tokens lifted from the v1 Figma prototype.
// Display type is Righteous (as in Figma); body copy stays on the iOS system font.
enum Theme {
    static let cream = Color(hex: 0xF9EEE6)
    static let blush = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x333333)
    static let sky = Color(hex: 0xB3E5FF)
    static let mint = Color(hex: 0xCFE8D6)
    static let alert = Color(hex: 0xF57470)
    static let butter = Color(hex: 0xFFF1C2)
    static let hairline = Color(hex: 0x333333).opacity(0.15)

    static let stroke: CGFloat = 2

    // A radius ladder instead of one radius everywhere: surfaces > buttons > inputs > chips.
    enum Radius {
        static let card: CGFloat = 28
        static let button: CGFloat = 20
        static let input: CGFloat = 14
    }

    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Righteous", size: size, relativeTo: style)
    }

    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "Righteous-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// The outlined Figma surface. Use for the one or two primary blocks on a screen, not every row.
    func card(_ fill: Color = Theme.blush, padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.ink, lineWidth: Theme.stroke))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.sky
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
        configuration.label
            .font(Theme.display(22, relativeTo: .headline))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: shape)
            .overlay(shape.stroke(Theme.ink, lineWidth: Theme.stroke))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static func chunky(_ fill: Color, height: CGFloat = 56) -> ChunkyButtonStyle {
        ChunkyButtonStyle(fill: fill, height: height)
    }
}

/// Small outlined capsule, like the Figma "Edit" chip.
struct Chip: View {
    let text: String
    var fill: Color = .white
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).imageScale(.small) }
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(fill, in: Capsule())
        .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5))
    }
}

struct SectionTitle: View {
    let title: String
    var showsArrow = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(Theme.display(20, relativeTo: .title3))
            if showsArrow { Image(systemName: "arrow.right").font(.body.weight(.semibold)) }
        }
        .foregroundStyle(Theme.ink)
    }
}

struct Disclaimer: View {
    var body: some View {
        Label("Not medical advice. Confirm with your pharmacist.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(Theme.ink.opacity(0.75))
    }
}

/// White rounded tile used for a medication's pill art (Figma "pill-chip").
struct PillTile: View {
    var tint: Color
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(.white)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
            .overlay {
                Image(systemName: "pills.fill")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(tint, Theme.ink)
            }
    }
}

/// Small colored mark used in dense lists instead of a full tile.
struct MedDot: View {
    var tint: Color
    var body: some View {
        Circle().fill(tint).frame(width: 12, height: 12)
            .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
    }
}
