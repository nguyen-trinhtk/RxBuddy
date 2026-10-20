import SwiftUI

/// Today's plan: interactions first, then the dose timeline.
/// `isNew` is the end of the scan flow and adds the "Turn on reminders" action.
struct PlanView: View {
    @Environment(AppState.self) private var state
    var isNew: Bool
    @State private var selected: Clash?
    @State private var remindersOn = false

    // Pharmacist-required first: it's the one the user has to act on.
    private var clashes: [Clash] {
        state.clashes.filter { $0.type == .pharmacistRequired } + state.clashes.filter { $0.type != .pharmacistRequired }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Today's Plan") { BackButton() }
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !clashes.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(title: "Interactions")
                            ForEach(clashes) { clash in
                                ConflictCard(clash: clash) { selected = clash }
                            }
                            Disclaimer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Doses")
                        Timeline(events: state.schedule)
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                if isNew {
                    Button { remindersOn = true } label: {
                        Label(remindersOn ? "Reminders on" : "Turn on reminders",
                              systemImage: remindersOn ? "checkmark" : "bell")
                    }
                    .buttonStyle(.chunky(remindersOn ? Theme.mint : Theme.sky))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.cream)
                }
            }
        }
        .background(Theme.cream)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selected) { ClashDetail(clash: $0) }
    }
}

// MARK: - Conflicts

/// Status band, then the two drugs joined by what keeps them apart. Tap for the label source.
struct ConflictCard: View {
    @Environment(AppState.self) private var state
    let clash: Clash
    var onDetails: () -> Void

    private var urgent: Bool { clash.type == .pharmacistRequired }

    var body: some View {
        Button(action: onDetails) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(urgent ? "Ask your pharmacist" : "Spaced out",
                          systemImage: urgent ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Spacer()
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(urgent ? Theme.alert : Theme.mint)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: Theme.stroke) }

                pair.padding(18)
            }
            .foregroundStyle(Theme.ink)
            .background(urgent ? Theme.blush : .white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
        }
        .buttonStyle(.plain)
    }

    private var pair: some View {
        let a = clash.drugs[0], b = clash.drugs[1]
        return VStack(alignment: .leading, spacing: 0) {
            drugRow(a)
            HStack(spacing: 14) {
                // Connector: dashed for "kept apart", a cross for "don't combine".
                ZStack {
                    Rectangle().fill(.clear).frame(width: 28, height: 36)
                    if urgent {
                        Rectangle().fill(Theme.alert).frame(width: Theme.stroke, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Theme.alert, in: Circle())
                    } else {
                        Path { p in p.move(to: .init(x: 14, y: 0)); p.addLine(to: .init(x: 14, y: 36)) }
                            .stroke(Theme.ink, style: .init(lineWidth: Theme.stroke, dash: [4, 4]))
                            .frame(width: 28, height: 36)
                    }
                }
                Text(urgent ? "Don't combine" : "\(clash.gapHours ?? 0)h apart")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(urgent ? .white : Theme.mint, in: Capsule())
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.5))
            }
            drugRow(b)
        }
    }

    private func drugRow(_ ingredient: String) -> some View {
        HStack(spacing: 14) {
            PillIcon(tint: state.med(for: ingredient)?.tint ?? Theme.sky, size: 28)
            Text(ingredient.capitalized).font(Theme.display(19, relativeTo: .headline))
            Spacer(minLength: 8)
            if let time = state.schedule.first(where: { $0.ingredient == ingredient })?.time {
                Text(time).font(.subheadline.weight(.semibold).monospacedDigit()).opacity(0.7)
            }
        }
    }
}

struct ClashDetail: View {
    let clash: Clash
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Chip(text: clash.type == .pharmacistRequired ? "Ask your pharmacist" : "Spaced out",
                     fill: clash.type == .pharmacistRequired ? Theme.blush : Theme.mint)
                Spacer()
                Button("Close") { dismiss() }.font(.body.weight(.semibold)).tint(Theme.ink)
            }
            Text(clash.drugs.map(\.capitalized).joined(separator: " + ")).font(Theme.display(26))

            VStack(alignment: .leading, spacing: 8) {
                Label("Label", systemImage: "doc.text").font(.subheadline.weight(.semibold))
                Text(clash.source.quote).font(.callout).italic()
                Text("DailyMed · \(clash.source.section)").font(.footnote).opacity(0.6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous))

            Disclaimer()
            Spacer()
        }
        .foregroundStyle(Theme.ink)
        .padding(24)
        .background(Theme.cream)
        .presentationDetents([.medium])
    }
}

// MARK: - Timeline

/// Read-only: time capsules on a vertical rail, plain dose rows beside each.
struct Timeline: View {
    let events: [DoseEvent]

    private var grouped: [(String, [DoseEvent])] {
        Dictionary(grouping: events, by: \.time).sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(grouped.enumerated()), id: \.element.0) { index, group in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        Text(group.0).font(.footnote.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.white, in: Capsule())
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: Theme.stroke))
                        if index < grouped.count - 1 {
                            Rectangle().fill(Theme.ink.opacity(0.35)).frame(width: Theme.stroke).frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 58)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(group.1) { DoseLine(dose: $0) }
                    }
                    .padding(.top, 3)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Theme.ink)
    }
}

struct DoseLine: View {
    @Environment(AppState.self) private var state
    let dose: DoseEvent

    private var med: Medication? { state.med(for: dose.ingredient) }
    private var flagged: Bool { state.clashes(for: dose.ingredient).contains { $0.type == .pharmacistRequired } }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            MedDot(tint: med?.tint ?? Theme.sky)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dose.ingredient.capitalized).font(.body.weight(.semibold))
                    if flagged {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.alert)
                            .accessibilityLabel("Interaction")
                    }
                    if dose.status == .taken {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.sky)
                            .accessibilityLabel("Taken")
                    }
                }
                Text([med?.strength, dose.note].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(Theme.ink.opacity(0.65))
            }
        }
        .opacity(dose.status == .upcoming ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

/// White tile with pill art at small sizes (timeline and conflict rows).
struct PillIcon: View {
    var tint: Color
    var size: CGFloat = 42

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).stroke(Theme.ink, lineWidth: size < 32 ? 1.5 : Theme.stroke))
            .overlay {
                Image(systemName: "pills.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(tint, Theme.ink)
            }
            .frame(width: size, height: size)
    }
}
