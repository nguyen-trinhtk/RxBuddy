import SwiftUI

struct PrescriptionsView: View {
    @Environment(AppState.self) private var state
    @State private var editing: Medication?

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            TopBar(title: "All Prescriptions")
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(state.meds) { med in
                        MedReviewCard(med: med) { editing = med }
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.cream)
        .medEditSheet($editing, in: $state.meds)
        // `-edit YES` launch argument opens the first prescription's sheet (handy for previews).
        .onAppear { if UserDefaults.standard.bool(forKey: "edit") { editing = state.meds.first } }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            TopBar(title: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Your day")
                        DayRows(wake: $state.wake, sleep: $state.sleep)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Reminders")
                        Toggle(isOn: $state.remindersOn) { Label("Dose reminders", systemImage: "bell") }
                            .tint(Theme.sky)
                            .foregroundStyle(Theme.ink)
                            .padding(.vertical, 6)
                    }
                    Disclaimer()
                }
                .padding(20)
            }
        }
        .background(Theme.cream)
    }
}
