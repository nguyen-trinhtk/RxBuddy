import SwiftUI

@main
struct RxBuddyApp: App {
    @State private var state = AppState()

    init() { Theme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.light)
        }
    }
}

enum Tab: String, CaseIterable {
    case home, add, prescriptions, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .add: "Scan"
        case .prescriptions: "Prescriptions"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .add: "camera"
        case .prescriptions: "book.closed"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    // `-tab prescriptions` launch argument jumps to a tab (handy for previews).
    @State private var tab = Tab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .home: HomeView()
                case .add: AddView()
                case .prescriptions: PrescriptionsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(selection: $tab)
        }
        .background(Theme.cream.ignoresSafeArea())
    }
}

/// Bottom navigation in the app's card language: a floating white bar with the 2pt ink outline,
/// the active tab sits in a sky tile like the chunky buttons.
struct TabBar: View {
    @Binding var selection: Tab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                let on = tab == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: on ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 19, weight: .medium))
                            .frame(height: 24)
                        Text(tab.title)
                            .font(Theme.display(12, relativeTo: .caption2))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.ink.opacity(on ? 1 : 0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.sky)
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
                                .matchedGeometryEffect(id: "active", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.cream.ignoresSafeArea(edges: .bottom))
    }
}

/// Top app bar from the Figma: account icon, centered title, bell on the right, hairline below.
struct TopBar<Leading: View>: View {
    let title: String
    @ViewBuilder var leading: Leading

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(title).font(Theme.display(24, relativeTo: .title2))
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .padding(.horizontal, 48)
                HStack(spacing: 4) {
                    leading
                    Spacer()
                    BarIcon(system: "bell")
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 8)
            .frame(height: 56)
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .background(Theme.cream)
    }
}

extension TopBar where Leading == BarIcon {
    init(title: String) {
        self.init(title: title) { BarIcon(system: "person.crop.circle") }
    }
}

struct BarIcon: View {
    let system: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
