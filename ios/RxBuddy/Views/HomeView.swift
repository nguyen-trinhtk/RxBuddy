import SwiftUI

enum Route: Hashable {
    case review([Medication], warnings: [String] = []), manual, plan, newPlan
}

extension View {
    /// Shared destinations for the Home and Add stacks.
    func routes(_ path: Binding<[Route]>) -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .review(let meds, let warnings): ReviewView(path: path, meds: meds, warnings: warnings)
            case .manual: ReviewView(path: path, meds: nil)
            case .plan: PlanView(isNew: false)
            case .newPlan: PlanView(isNew: true)
            }
        }
    }
}

struct HomeView: View {
    @Environment(AppState.self) private var state
    // `-screen plan` launch argument opens Today's Plan (handy for previews).
    @State private var path: [Route] = UserDefaults.standard.string(forKey: "screen") == "plan" ? [.plan] : []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TopBar(title: "Home")
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(title: "Up next")
                            if let next = state.nextDose, let med = state.med(for: next.ingredient) {
                                NextDoseCard(dose: next, med: med)
                                    .id(next.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                            } else {
                                Text("All done").font(.body).foregroundStyle(Theme.ink.opacity(0.7))
                            }
                        }
                        NavigationLink(value: Route.plan) { PlanLinkRow() }
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .background(Theme.cream)
            .toolbar(.hidden, for: .navigationBar)
            .routes($path)
        }
    }
}

/// Row that opens Today's Plan: progress, an interaction flag if any, and a chevron so it reads as tappable.
struct PlanLinkRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let taken = state.schedule.filter { $0.status == .taken }.count
        let urgent = state.clashes.filter { $0.type == .pharmacistRequired }.count
        HStack(spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 22))
                .frame(width: 48, height: 48)
                .background(Theme.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.ink, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Plan").font(Theme.display(22, relativeTo: .headline))
                HStack(spacing: 10) {
                    Text("\(taken)/\(state.schedule.count) taken")
                    if urgent > 0 {
                        Label {
                            Text("\(urgent)")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.alert)
                        }
                            .accessibilityLabel("\(urgent) interaction to review")
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.75))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .background(Theme.sky, in: Circle())
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
        }
        .foregroundStyle(Theme.ink)
        .card(.white, padding: 16)
        .contentShape(Rectangle())
    }
}

/// The Figma medication card: pill tile, name, dose, then Skip / Done.
/// Tapping stamps the card ("Taken" / "Skipped"), then it slides away and the next dose slides in.
struct NextDoseCard: View {
    @Environment(AppState.self) private var state
    let dose: DoseEvent
    let med: Medication
    @State private var outcome: DoseEvent.Status?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                PillTile(tint: med.tint)
                VStack(alignment: .leading, spacing: 6) {
                    Text(med.ingredient.capitalized)
                        .font(Theme.display(28))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(med.strength).font(.title3)
                    Text(dose.time)
                        .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(Theme.ink).frame(height: Theme.stroke)
            HStack(spacing: 12) {
                Button("Skip") { finish(.skipped) }.buttonStyle(.chunky(.white))
                Button("Done") { finish(.taken) }.buttonStyle(.chunky)
            }
        }
        .opacity(outcome == nil ? 1 : 0.1)
        .foregroundStyle(Theme.ink)
        .card(fill)
        .overlay { if let outcome { stamp(outcome) } }
        .scaleEffect(outcome == nil ? 1 : 0.97)
        .allowsHitTesting(outcome == nil)
        .sensoryFeedback(.success, trigger: outcome) { _, new in new == .taken }
        .sensoryFeedback(.impact(weight: .light), trigger: outcome) { _, new in new == .skipped }
    }

    private var fill: Color {
        switch outcome {
        case .taken: Theme.sky
        case .skipped: Theme.cream
        default: Theme.blush
        }
    }

    private func stamp(_ status: DoseEvent.Status) -> some View {
        let taken = status == .taken
        return VStack(spacing: 10) {
            Image(systemName: taken ? "checkmark" : "forward.end")
                .font(.system(size: 34, weight: .bold))
                .frame(width: 76, height: 76)
                .background(taken ? Theme.mint : .white, in: Circle())
                .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.stroke))
            Text(taken ? "Taken" : "Skipped").font(Theme.display(26))
        }
        .foregroundStyle(Theme.ink)
        .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    private func finish(_ status: DoseEvent.Status) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { outcome = status }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { state.mark(dose, status) }
        }
    }
}

struct ScanningOverlay: View {
    var body: some View {
        ZStack {
            Theme.ink.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(Theme.ink)
                Text("Reading label").font(Theme.display(22))
            }
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 32).padding(.horizontal, 40)
            .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
        }
        .transition(.opacity)
    }
}

/// Back button for pushed screens, in the top bar's leading slot.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        BarIcon(system: "chevron.left") { dismiss() }
            .accessibilityLabel("Back")
    }
}
