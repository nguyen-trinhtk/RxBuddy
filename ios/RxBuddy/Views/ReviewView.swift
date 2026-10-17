import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var state
    @Binding var path: [Route]
    @State private var meds: [Medication]
    @State private var editing: Medication?
    @State private var analyzing = false

    init(path: Binding<[Route]>, manual: Bool) {
        _path = path
        let blank = Medication(rawName: "", ingredient: "", strength: "", frequencyPerDay: 1, withFood: .any, confidence: 1)
        _meds = State(initialValue: manual ? [blank] : Sample.meds)
        _editing = State(initialValue: manual ? blank : nil)
    }

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            TopBar(title: "New Prescription") { BackButton() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(meds) { med in
                        MedReviewCard(med: med) { editing = med }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Your day")
                        DayRows(wake: $state.wake, sleep: $state.sleep)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: analyze) {
                    HStack(spacing: 10) {
                        if analyzing { ProgressView().tint(Theme.ink) }
                        Text(analyzing ? "Checking" : "Build schedule")
                    }
                }
                .buttonStyle(.chunky)
                .disabled(analyzing)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Theme.cream)
            }
        }
        .background(Theme.cream)
        .toolbar(.hidden, for: .navigationBar)
        .medEditSheet($editing, in: $meds)
    }

    private func analyze() {
        analyzing = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            state.meds = meds
            analyzing = false
            path.append(.newPlan)
        }
    }
}

/// The Figma prescription card: name with an Edit chip and a short dosing line.
struct MedReviewCard: View {
    let med: Medication
    var onEdit: () -> Void

    private var needsCheck: Bool { med.confidence < 0.75 || med.rxcui == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(med.ingredient.isEmpty ? "New medication" : med.ingredient.capitalized)
                    .font(Theme.display(26))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if needsCheck {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .accessibilityLabel("Low confidence, please check")
                }
                Spacer()
                Button(action: onEdit) { Chip(text: "Edit", fill: Theme.blush) }
                    .buttonStyle(.plain)
            }
            Text("\(med.dosing) · \(med.withFood.label.lowercased())")
                .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.75))
        }
        .foregroundStyle(Theme.ink)
        .card(needsCheck ? Theme.butter : .white)
    }
}

extension View {
    /// Bottom sheet that edits a copy of `item`; Save writes it back into `list`, Remove deletes it.
    func medEditSheet(_ item: Binding<Medication?>, in list: Binding<[Medication]>) -> some View {
        sheet(item: item) { med in
            MedEditSheet(med: med,
                         onSave: { saved in
                             if let i = list.wrappedValue.firstIndex(where: { $0.id == saved.id }) { list.wrappedValue[i] = saved }
                         },
                         onRemove: { withAnimation { list.wrappedValue.removeAll { $0.id == med.id } } })
        }
    }
}

/// The Figma "New Prescription" form, presented as a bottom sheet with Cancel / Save.
struct MedEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Medication
    var onSave: (Medication) -> Void
    var onRemove: () -> Void

    init(med: Medication, onSave: @escaping (Medication) -> Void, onRemove: @escaping () -> Void) {
        _draft = State(initialValue: med)
        self.onSave = onSave
        self.onRemove = onRemove
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(draft.ingredient.isEmpty ? "New medication" : draft.ingredient.capitalized)
                    .font(Theme.display(26))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Button(role: .destructive) { onRemove(); dismiss() } label: {
                    Image(systemName: "trash").font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .tint(Theme.alert)
                .accessibilityLabel("Remove")
            }

            Field(label: "Name") {
                TextField("Medication", text: Binding(get: { draft.ingredient.capitalized },
                                                      set: { draft.ingredient = $0.lowercased() }))
            }
            HStack(spacing: 12) {
                Field(label: "Dosage") { TextField("50 mg", text: $draft.strength) }
                Field(label: "Times a day") {
                    Stepper(value: $draft.frequencyPerDay, in: 1...6) { Text("\(draft.frequencyPerDay)") }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Food").font(.subheadline.weight(.semibold))
                Picker("Food", selection: $draft.withFood) {
                    ForEach(FoodRule.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }.buttonStyle(.chunky(.white))
                Button("Save") { onSave(draft); dismiss() }.buttonStyle(.chunky)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.cream)
    }
}

struct Field<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            content
                .font(.body)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.input, style: .continuous).stroke(Theme.ink, lineWidth: 1.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wake and bed times as two plain rows (no card), shared by Review and Settings.
struct DayRows: View {
    @Binding var wake: Date
    @Binding var sleep: Date

    var body: some View {
        VStack(spacing: 0) {
            row("Wake up", icon: "sunrise", time: $wake)
            Rectangle().fill(Theme.hairline).frame(height: 1)
            row("Bedtime", icon: "moon", time: $sleep)
        }
    }

    private func row(_ label: String, icon: String, time: Binding<Date>) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            DatePicker(label, selection: time, displayedComponents: .hourAndMinute).labelsHidden()
        }
        .font(.body)
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
    }
}
