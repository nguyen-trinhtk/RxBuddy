import SwiftUI
import PhotosUI

/// Scan tab: scan a label (camera or gallery) or enter a medication by hand.
struct AddView: View {
    // `-screen review` launch argument opens the review screen (handy for previews).
    @State private var path: [Route] = UserDefaults.standard.string(forKey: "screen") == "review" ? [.review] : []
    @State private var photo: PhotosPickerItem?
    @State private var scanning = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TopBar(title: "Scan New Prescription")
                ScrollView {
                    VStack(spacing: 20) {
                        scanCard
                        Button { path.append(.manual) } label: {
                            Label("Enter manually", systemImage: "keyboard")
                        }
                        .buttonStyle(.chunky(.white))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .background(Theme.cream)
            .toolbar(.hidden, for: .navigationBar)
            .routes($path)
            .overlay { if scanning { ScanningOverlay() } }
            .onChange(of: photo) { _, item in if item != nil { startScan() } }
        }
    }

    private var scanCard: some View {
        VStack(spacing: 24) {
            Button(action: startScan) {
                VStack(spacing: 16) {
                    Image(systemName: "camera")
                        .font(.system(size: 44, weight: .regular))
                        .frame(width: 120, height: 120)
                        .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.ink, lineWidth: Theme.stroke))
                    Text("Take Photo").font(Theme.display(32))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Scan a prescription label")

            PhotosPicker(selection: $photo, matching: .images) {
                Text("Choose from Gallery")
            }
            .buttonStyle(.chunky)
        }
        .card(padding: 24)
    }

    private func startScan() {
        withAnimation { scanning = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { scanning = false }
            photo = nil
            path.append(.review)
        }
    }
}
