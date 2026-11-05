import SwiftUI

enum Onboarding {
    private static let seenKey = "Onboarding.seen"

    /// New installs only: existing users with certificates or sources skip it.
    @MainActor static var shouldShow: Bool {
        guard !UserDefaults.standard.bool(forKey: seenKey) else { return false }
        if !Storage.shared.getAllCertificates().isEmpty || !Storage.shared.getSources().isEmpty {
            markSeen()
            return false
        }
        return true
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var addingCertificate = false
    @State private var addingSource = false

    private struct Page {
        let icon: String
        let title: String
        let detail: String
    }

    private let pages = [
        Page(icon: "app.gift.fill", title: "Welcome to Feather", detail: "Sign and install apps right on your iPhone, no computer needed."),
        Page(icon: "checkmark.seal.fill", title: "Add a Certificate", detail: "Feather signs apps with your certificate. Import your .p12 and .mobileprovision files to get started."),
        Page(icon: "globe.desk.fill", title: "Add a Source", detail: "Sources are app libraries. Add one from the featured list or paste a source link."),
        Page(icon: "signature", title: "Sign and Install", detail: "Pick an app, tap Sign, then Install. Swipe on apps in your Library for quick actions.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { dismiss() }
                    .opacity(page < pages.count - 1 ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], index: index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation(.smooth) { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $addingCertificate) { CertificatesAddView() }
        .sheet(isPresented: $addingSource) { SourcesAddView() }
    }

    private func pageView(_ item: Page, index: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: item.icon)
                .font(.system(size: 76))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
            Text(item.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(item.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            if index == 1 {
                Button("Add Certificate", systemImage: "plus") { addingCertificate = true }
                    .buttonStyle(.bordered)
            } else if index == 2 {
                Button("Add Source", systemImage: "plus") { addingSource = true }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Spacer()
        }
    }
}
