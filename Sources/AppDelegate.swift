import Cocoa
import ServiceManagement

// MARK: - Localization helpers
// Strings live in Resources/<lang>.lproj/Localizable.strings. English is the default and fallback.

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    // Numbers follow the language of the translation in use, so a menu never mixes the two.
    String(format: NSLocalizedString(key, comment: ""),
           locale: Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en"),
           arguments: args)
}

/// "1h 05m", "45m"... localized by the system.
func formatDuration(_ seconds: TimeInterval) -> String {
    let f = DateComponentsFormatter()
    f.unitsStyle = .abbreviated
    f.allowedUnits = seconds >= 86400 ? [.day, .hour, .minute] : [.hour, .minute]
    f.zeroFormattingBehavior = seconds > 0 ? .dropAll : .default
    return f.string(from: seconds > 0 ? max(60, seconds) : 0) ?? "0m"
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let awake = AwakeController()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        Notifier.setUp(onExtend: { [weak self] in self?.awake.extend(minutes: 30) },
                       onStopNow: { [weak self] in self?.awake.stop() })
        awake.onChange = { [weak self] in self?.refreshStatusItem() }
        awake.onTimerFinished = { Notifier.post(L("notify.timer")) }
        awake.onWatchedAppQuit = { name in Notifier.post(L("notify.appquit", name)) }
        awake.onWarningChange = { date in
            if let date = date { Notifier.scheduleWarning(at: date) } else { Notifier.cancelWarning() }
        }
        refreshStatusItem()

        // For testing only, see Development in the README. The buttons do nothing as there is no session.
        if CommandLine.arguments.contains("--notify-test") {
            Notifier.scheduleWarning(at: Date().addingTimeInterval(10))
        }

        // Every minute: refresh the menu bar text and enforce the low battery rule.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        awake.stop() // also saves the current session into the daily log
    }

    // MARK: Periodic work

    private func tick() {
        if awake.isActive, Prefs.stopOnLowBattery,
           let battery = BatteryInfo.read(),
           !battery.onAC, battery.percent < Prefs.lowBatteryThreshold {
            awake.stop()
            Notifier.post(L("notify.lowbattery", Prefs.lowBatteryThreshold))
        }
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(active: awake.isActive)
        button.imagePosition = .imageLeft

        if Prefs.showBatteryInMenuBar, let battery = BatteryInfo.read() {
            button.title = " \(battery.percent)%"
        } else {
            button.title = ""
        }
    }

    // MARK: Menu

    /// The menu is rebuilt every time it opens, so the numbers are always fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Status line
        let statusText: String
        if awake.isActive {
            if let name = awake.watchedAppName {
                statusText = L("status.on.untilapp", name)
            } else if let left = awake.minutesLeft {
                statusText = L("status.on.remaining", left)
            } else {
                statusText = L("status.on.indefinite")
            }
        } else {
            statusText = L("status.off")
        }
        menu.addItem(disabledItem(statusText))
        menu.addItem(.separator())

        // Controls
        if awake.isActive {
            menu.addItem(item(L("action.stop"), #selector(stopAwake)))
        } else {
            menu.addItem(timedItem(L("action.indefinite"), minutes: 0))
            menu.addItem(timedItem(L("action.30m"), minutes: 30))
            menu.addItem(timedItem(L("action.1h"), minutes: 60))
            menu.addItem(timedItem(L("action.2h"), minutes: 120))
            menu.addItem(timedItem(L("action.4h"), minutes: 240))
            menu.addItem(untilAppItem())
        }
        menu.addItem(item(L("action.displayoff"), #selector(turnOffDisplay)))
        menu.addItem(.separator())

        // Statistics submenu
        let statsItem = NSMenuItem(title: L("stats.title"), action: nil, keyEquivalent: "")
        statsItem.submenu = buildStatsMenu()
        menu.addItem(statsItem)
        menu.addItem(holdersItem())
        menu.addItem(.separator())

        // Options
        menu.addItem(toggleItem(L("option.display"), #selector(toggleDisplay), on: Prefs.keepDisplayOn))
        menu.addItem(toggleItem(L("option.lowbattery", Prefs.lowBatteryThreshold),
                                #selector(toggleLowBattery), on: Prefs.stopOnLowBattery))
        menu.addItem(toggleItem(L("option.showpercent"), #selector(toggleShowPercent), on: Prefs.showBatteryInMenuBar))
        menu.addItem(toggleItem(L("option.login"), #selector(toggleLogin), on: launchAtLogin))
        if Notifier.isDenied() {
            menu.addItem(item(L("menu.notificationsoff"), #selector(openNotificationSettings)))
        }
        menu.addItem(.separator())

        // Support and about
        menu.addItem(item(L("menu.support"), #selector(openDonation)))
        menu.addItem(item(L("menu.sourcecode"), #selector(openRepo)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func untilAppItem() -> NSMenuItem {
        let apps = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular && $0.processIdentifier != getpid()
                    && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            .sorted { ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "") == .orderedAscending }

        let m = NSMenu()
        for app in apps {
            let i = item(app.localizedName ?? app.bundleIdentifier ?? "?", #selector(startUntilApp(_:)))
            i.representedObject = app
            // Copied because NSRunningApplication shares its icon, and the menu needs a small one.
            if let icon = app.icon?.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                i.image = icon
            }
            m.addItem(i)
        }
        if apps.isEmpty { m.addItem(disabledItem(L("action.untilapp.none"))) }

        let parent = NSMenuItem(title: L("action.untilapp"), action: nil, keyEquivalent: "")
        parent.submenu = m
        return parent
    }

    private func holdersItem() -> NSMenuItem {
        let holders = WakeHolders.entries()
        let m = NSMenu()
        for entry in holders {
            let i = item(entry.title, #selector(ignoreHolderClick))
            i.toolTip = entry.reason
            m.addItem(i)
        }
        if holders.isEmpty { m.addItem(disabledItem(L("holders.none"))) }

        let parent = NSMenuItem(title: L("holders.title", holders.count), action: nil, keyEquivalent: "")
        parent.submenu = m
        return parent
    }

    private func buildStatsMenu() -> NSMenu {
        let m = NSMenu()

        // Battery
        if let b = BatteryInfo.read() {
            let state: String
            if b.isFull { state = L("battery.state.full") }
            else if b.isCharging { state = L("battery.state.charging") }
            else if b.onAC { state = L("battery.state.plugged") }
            else { state = L("battery.state.discharging") }
            m.addItem(disabledItem(L("battery.level", b.percent, state)))

            if let minutes = b.minutesRemaining {
                let key = b.isCharging ? "battery.timetofull" : "battery.timeleft"
                m.addItem(disabledItem(L(key, formatDuration(TimeInterval(minutes * 60)))))
            }
            if let health = BatteryInfo.systemHealthPercent() ?? b.healthPercent {
                m.addItem(disabledItem(L("battery.health", health)))
            }
            if let cycles = b.cycleCount { m.addItem(disabledItem(L("battery.cycles", cycles))) }
            if let temp = b.temperatureC { m.addItem(disabledItem(L("battery.temp", temp))) }
        } else {
            m.addItem(disabledItem(L("battery.none")))
        }
        m.addItem(.separator())

        // Awake usage
        let live = awake.liveSessionSeconds
        if awake.isActive {
            m.addItem(disabledItem(L("awake.session", formatDuration(live))))
        }
        m.addItem(disabledItem(L("awake.today", formatDuration(UsageLog.total(lastDays: 1, liveSession: live)))))
        m.addItem(disabledItem(L("awake.week", formatDuration(UsageLog.total(lastDays: 7, liveSession: live)))))
        m.addItem(.separator())

        // System
        m.addItem(disabledItem(L("system.uptime", formatDuration(ProcessInfo.processInfo.systemUptime))))
        m.addItem(disabledItem(L("system.thermal", thermalDescription())))
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            m.addItem(disabledItem(L("system.lowpower")))
        }
        return m
    }

    private func thermalDescription() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return L("thermal.nominal")
        case .fair: return L("thermal.fair")
        case .serious: return L("thermal.serious")
        case .critical: return L("thermal.critical")
        @unknown default: return L("thermal.nominal")
        }
    }

    // MARK: Menu item helpers

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func timedItem(_ title: String, minutes: Int) -> NSMenuItem {
        let i = item(title, #selector(startTimed(_:)))
        i.tag = minutes // 0 means no time limit
        return i
    }

    private func toggleItem(_ title: String, _ action: Selector, on: Bool) -> NSMenuItem {
        let i = item(title, action)
        i.state = on ? .on : .off
        return i
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    // MARK: Actions

    @objc private func startTimed(_ sender: NSMenuItem) {
        Notifier.requestPermission()
        awake.start(minutes: sender.tag == 0 ? nil : sender.tag)
    }

    @objc private func startUntilApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication else { return }
        Notifier.requestPermission()
        awake.start(untilQuitOf: app)
    }

    @objc private func stopAwake() { awake.stop() }

    /// Does nothing on purpose: macOS shows no toolTip on a disabled menu item, so these need an action.
    @objc private func ignoreHolderClick() {}

    /// Short delay so the hand still on the mouse after the click does not wake the display right away.
    @objc private func turnOffDisplay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            do { try process.run() } catch { NSSound.beep() }
        }
    }

    @objc private func toggleDisplay() {
        Prefs.keepDisplayOn.toggle()
        // If already running, restart with the new mode but keep the remaining time.
        if awake.isActive { awake.start(minutes: awake.minutesLeft, continuing: true) }
    }

    @objc private func toggleLowBattery() { Prefs.stopOnLowBattery.toggle() }

    @objc private func toggleShowPercent() {
        Prefs.showBatteryInMenuBar.toggle()
        refreshStatusItem()
    }

    private var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    @objc private func toggleLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSSound.beep() // usually means the app is not in /Applications or not signed
        }
    }

    @objc private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The donation link is read from Info.plist (key TazzaDonationURL), set in build.sh.
    @objc private func openDonation() { openURL(forInfoKey: "TazzaDonationURL") }
    @objc private func openRepo() { openURL(forInfoKey: "TazzaRepoURL") }

    private func openURL(forInfoKey key: String) {
        if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: s) {
            NSWorkspace.shared.open(url)
        }
    }
}
