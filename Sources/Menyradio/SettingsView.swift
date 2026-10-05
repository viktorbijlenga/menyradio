import SwiftUI
import ServiceManagement
import Sparkle

struct SettingsView: View {
    let library: RadioLibrary
    let updater: SPUUpdater
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kanaler i menyn").font(.headline)
            List {
                Section("Favoriter") {
                    ForEach(library.favourites) { channel in
                        HStack {
                            Text(channel.name)
                            Spacer()
                            Button { library.move(channel.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(library.favouriteIDs.first == channel.id).accessibilityLabel("Flytta \(channel.name) upp")
                            Button { library.move(channel.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(library.favouriteIDs.last == channel.id).accessibilityLabel("Flytta \(channel.name) ned")
                        }
                    }
                }
                Section("Tillgängliga kanaler") {
                    ForEach(library.channels) { channel in
                        Toggle(channel.name, isOn: Binding(get: { library.favouriteIDs.contains(channel.id) }, set: { library.setFavourite(channel, selected: $0) }))
                    }
                }
            }
            HStack {
                Button(library.loading ? "Hämtar…" : "Uppdatera kanaler") { Task { await library.refresh(force: true) } }.disabled(library.loading)
                if let error = library.error { Text(error).font(.caption).foregroundStyle(.secondary) }
            }
            Toggle("Starta vid inloggning", isOn: Binding(get: { loginEnabled }, set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    loginEnabled = SMAppService.mainApp.status == .enabled
                    loginError = SMAppService.mainApp.status == .requiresApproval ? "Godkänn appen under Inloggningsobjekt i Systeminställningar." : nil
                } catch { loginError = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
            }))
            Toggle("Sök automatiskt efter appuppdateringar", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.automaticallyChecksForUpdates = $0 }
            ))
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
            Text("En fristående app för Sveriges Radio. Ingen koppling till Sveriges Radio AB.").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(width: 370, height: 510)
        .onAppear { loginEnabled = SMAppService.mainApp.status == .enabled; NSApp.activate(ignoringOtherApps: true) }
    }
}
