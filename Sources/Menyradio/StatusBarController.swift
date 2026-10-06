import AppKit
import SwiftUI
import Observation
import Sparkle

/// A standard macOS status menu, with a tooltip on the actual status button.
@MainActor final class StatusBarController: NSObject, NSMenuDelegate {
    let player: RadioPlayer
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private let library: RadioLibrary
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let maximumMenuWidth: CGFloat = 360
    private var textWidth: CGFloat { maximumMenuWidth - 56 }
    private var volumeControls: VolumeMenuView?
    private let volumeItem = NSMenuItem()
    private let volumeTitleItem = NSMenuItem(title: "Volym", action: nil, keyEquivalent: "")
    private var muteItem: NSMenuItem?
    private let footerSeparator = NSMenuItem.separator()
    private let playbackSeparator = NSMenuItem.separator()
    private let playingChannelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let metadataItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let playbackStateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stoppa", action: nil, keyEquivalent: "")
    private var settingsWindow: NSWindow?
    private var airPlayWindow: AirPlayWindow?
    private var channelItems: [Int: NSMenuItem] = [:]
    private var programmeTask: Task<Void, Never>?

    init(library: RadioLibrary, player: RadioPlayer) {
        self.library = library
        self.player = player
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.setAccessibilityLabel("Menyradio")
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(playbackSeparator)
        for item in [playingChannelItem, metadataItem, playbackStateItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        stopItem.target = self
        stopItem.action = #selector(stop)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        volumeTitleItem.isEnabled = false
        menu.addItem(volumeTitleItem)
        let controls = VolumeMenuView(player: player)
        controls.fitMenuWidth(242)
        volumeControls = controls
        volumeItem.view = controls
        volumeItem.isEnabled = true
        menu.addItem(volumeItem)
        let muteItem = actionItem("Ljud av", action: #selector(toggleMute))
        self.muteItem = muteItem
        menu.addItem(muteItem)
        menu.addItem(actionItem("AirPlay…", action: #selector(showAirPlay)))
        controls.onChange = { [weak self] in self?.updateVolumeMenu() }
        menu.addItem(footerSeparator)
        menu.addItem(actionItem("Inställningar…", action: #selector(showSettings)))
        menu.addItem(actionItem("Avsluta", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        observePlayer()
    }

    private func updateVolumeMenu() {
        volumeControls?.refresh()
        volumeTitleItem.title = "Volym – \(Int((player.volume * 100).rounded())) %"
        muteItem?.state = player.isMuted ? .on : .off
    }

    @objc private func toggleMute() {
        player.setMuted(!player.isMuted)
        updateVolumeMenu()
    }

    private func observePlayer() {
        withObservationTracking {
            let imageName = player.state == .playing ? "radio.fill" : "radio"
            let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Menyradio")
            image?.isTemplate = true
            statusItem.button?.image = image
            var lines = ["📻 \(player.channel?.name ?? "Menyradio")"]
            if let metadata = player.metadata, !metadata.isEmpty {
                lines.append("\(player.metadataIsSong ? "♫" : "🎙") \(metadata)")
            }
            if player.state != .playing { lines.append(player.state.rawValue) }
            let tooltip = lines.joined(separator: "\n")
            if statusItem.button?.toolTip != tooltip { statusItem.button?.toolTip = tooltip }
            statusItem.button?.setAccessibilityHelp(tooltip)
            updatePlaybackMenu()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observePlayer() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Keep playback rows alive so their titles and visibility can update
        // while the native menu is tracking mouse and keyboard input.
        while let first = menu.items.first, first !== playbackSeparator {
            menu.removeItem(at: 0)
        }
        channelItems.removeAll()
        var items = [textItem("Menyradio")]
        for channel in library.favourites {
            let item = actionItem(channel.name, action: #selector(selectChannel(_:)))
            item.representedObject = channel
            item.state = player.channel?.id == channel.id ? .on : .off
            channelItems[channel.id] = item
            items.append(item)
        }
        if library.favourites.isEmpty {
            items.append(textItem(library.loading ? "Hämtar kanaler…" : "Välj kanaler i inställningarna"))
        }
        if let error = library.error {
            items.append(textItem(error))
            items.append(actionItem("Försök igen", action: #selector(refreshChannels)))
        }
        for (index, item) in items.enumerated() { menu.insertItem(item, at: index) }
        updatePlaybackMenu()
        updateProgrammeTitles()
        volumeControls?.fitMenuWidth(242)
        volumeControls?.fitMenuWidth(min(maximumMenuWidth, menu.size.width))
    }

    private func updatePlaybackMenu() {
        let hasChannel = player.channel != nil
        playingChannelItem.title = menuText(player.channel?.name ?? "", width: textWidth)
        playingChannelItem.isHidden = !hasChannel
        metadataItem.title = menuText(player.metadata ?? "", width: textWidth)
        metadataItem.toolTip = player.metadata
        metadataItem.isHidden = !hasChannel || player.metadata?.isEmpty != false
        playbackStateItem.title = menuText(player.state.rawValue, width: textWidth)
        playbackStateItem.toolTip = player.state.rawValue
        playbackStateItem.isHidden = !hasChannel || player.state == .playing
        updateVolumeMenu()
        stopItem.isEnabled = hasChannel
        for (id, item) in channelItems {
            item.state = player.channel?.id == id ? .on : .off
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        programmeTask?.cancel()
        programmeTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.library.refreshProgrammes()
                guard !Task.isCancelled else { return }
                self.updateProgrammeTitles()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        programmeTask?.cancel()
        programmeTask = nil
    }

    private func updateProgrammeTitles() {
        for channel in library.favourites {
            guard let item = channelItems[channel.id] else { continue }
            if let programme = library.programmeTitle(for: channel.id) {
                let font = NSFont.menuFont(ofSize: 0)
                let detailFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                let name = menuText(channel.name, width: textWidth, font: font)
                let prefix = name + "   "
                let prefixWidth = (prefix as NSString).size(withAttributes: [.font: font]).width
                let compact = menuText(programme, width: max(0, textWidth - prefixWidth), font: detailFont)
                item.title = "\(prefix)\(compact)"
                let title = NSMutableAttributedString(string: prefix, attributes: [.font: font])
                title.append(NSAttributedString(string: compact, attributes: [
                    .font: detailFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
                item.attributedTitle = title
                item.toolTip = "\(channel.name) – \(programme)"
            } else {
                item.title = menuText(channel.name, width: textWidth)
                item.attributedTitle = nil
                item.toolTip = nil
            }
        }
    }

    private func textItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: menuText(title, width: textWidth), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: menuText(title, width: textWidth), action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func selectChannel(_ sender: NSMenuItem) {
        guard let channel = sender.representedObject as? Channel else { return }
        player.select(channel)
    }
    @objc private func stop() { player.stop() }
    @objc private func quit() { player.stop(); NSApp.terminate(nil) }
    @objc private func refreshChannels() { Task { await library.refresh(force: true) } }

    @objc private func showAirPlay() {
        menu.cancelTracking()
        // Present after the menu's tracking loop ends, so the picker receives
        // its own clicks instead of competing with NSMenu.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.airPlayWindow == nil {
                self.airPlayWindow = AirPlayWindow(player: self.player.routingPlayer)
            }
            self.airPlayWindow?.show()
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(library: library, updater: updaterController.updater))
            let window = NSWindow(contentViewController: controller)
            window.title = "Inställningar"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
