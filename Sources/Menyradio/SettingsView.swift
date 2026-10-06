import SwiftUI
import ServiceManagement
import Sparkle
import Combine

struct SettingsView: View {
    let library: RadioLibrary
    let updater: SPUUpdater
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var canCheckForUpdates = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kanaler i menyn").font(.headline)
                Spacer()
                Button {
                    Task { await library.refresh(force: true) }
                } label: {
                    Label(library.loading ? "Hämtar…" : "Uppdatera kanaler", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(library.loading)
            }
            Text("Flytta kanalerna till den ordning du vill ha i menyn.")
                .font(.caption).foregroundStyle(.secondary)
            List {
                Section("Kanaler i menyn") {
                    if library.favourites.isEmpty {
                        Text("Lägg till kanaler från listan nedan.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.favourites) { channel in
                        HStack(spacing: 8) {
                            Text(channel.name)
                            Spacer()
                            Button { library.move(channel.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(library.favourites.first?.id == channel.id)
                                .accessibilityLabel("Flytta \(channel.name) upp")
                                .help("Flytta upp")
                            Button { library.move(channel.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(library.favourites.last?.id == channel.id)
                                .accessibilityLabel("Flytta \(channel.name) ned")
                                .help("Flytta ned")
                            Button { library.setFavourite(channel, selected: false) } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Ta bort \(channel.name) från menyn")
                                .help("Ta bort från menyn")
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 2)
                    }
                }
                Section("Lägg till kanaler") {
                    if library.availableChannels.isEmpty {
                        Text(library.loading ? "Hämtar kanaler…" : "Alla tillgängliga kanaler finns i menyn.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.availableChannels) { channel in
                        HStack {
                            Text(channel.name)
                            Spacer()
                            Button { library.setFavourite(channel, selected: true) } label: { Image(systemName: "plus.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Lägg till \(channel.name) i menyn")
                                .help("Lägg till i menyn")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            if let error = library.error {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Allmänt").font(.headline)
                Toggle("Starta vid inloggning", isOn: Binding(get: { loginEnabled }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginEnabled = SMAppService.mainApp.status == .enabled
                        loginError = SMAppService.mainApp.status == .requiresApproval ? "Godkänn appen under Inloggningsobjekt i Systeminställningar." : nil
                    } catch { loginError = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
                }))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Uppdateringar").font(.headline)
                    Spacer()
                    Button("Sök nu…") { updater.checkForUpdates() }
                        .controlSize(.small)
                        .disabled(!canCheckForUpdates)
                        .accessibilityLabel("Sök efter appuppdateringar")
                }
                Toggle("Sök automatiskt efter uppdateringar", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Om Menyradio").font(.headline)
                    Spacer()
                    Link("Visa på GitHub", destination: URL(string: "https://github.com/viktorbijlenga/menyradio")!)
                        .font(.caption)
                }
                Text("En fristående app för Sveriges Radio. Ingen koppling till Sveriges Radio AB.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).frame(width: 410, height: 650)
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheckForUpdates = $0 }
        .onAppear { loginEnabled = SMAppService.mainApp.status == .enabled; NSApp.activate(ignoringOtherApps: true) }
    }
}
