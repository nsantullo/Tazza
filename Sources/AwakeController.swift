import Cocoa
import IOKit.pwr_mgt

/// Owns the power assertion. This is the same mechanism `caffeinate` uses, without spawning a process:
/// no sudo, no daemon, no kernel extension. Quitting the app releases the assertion automatically.
final class AwakeController {
    private var assertionID = IOPMAssertionID(0)
    private var endTimer: Timer?

    private(set) var isActive = false
    private(set) var sessionStart: Date?
    private(set) var endDate: Date?

    /// Called whenever the active state changes, so the UI can refresh.
    var onChange: (() -> Void)?

    /// Called when a timed session reaches its end, not when the user stops it.
    var onTimerFinished: (() -> Void)?

    /// Called with the date of the warning before the end, or nil when a planned warning is no longer valid.
    var onWarningChange: ((Date?) -> Void)?

    /// Called with the app name when the app a session was waiting for quits, not when the user stops the session.
    var onWatchedAppQuit: ((String) -> Void)?

    /// The app this session lasts until, if any.
    private(set) var watchedApp: NSRunningApplication?
    private var quitObserver: NSObjectProtocol?

    var watchedAppName: String? {
        watchedApp.map { $0.localizedName ?? $0.bundleIdentifier ?? "?" }
    }

    private let warningLead: TimeInterval = 5 * 60
    private let warningMinimumMinutes = 10

    /// Seconds elapsed in the current session (0 when inactive).
    var liveSessionSeconds: TimeInterval {
        guard isActive, let start = sessionStart else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Start (or restart) keeping the Mac awake. `minutes == nil` means no time limit.
    /// `continuing` is for a restart that keeps the remaining time, so a short remainder still gets its warning.
    func start(minutes: Int?, continuing: Bool = false) {
        let appToKeep = continuing ? watchedApp : nil
        stop()

        // IdleSystemSleep = like `caffeinate -i`; IdleDisplaySleep = like `caffeinate -d`.
        let type = Prefs.keepDisplayOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep

        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Tazza is keeping this Mac awake" as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else { return }

        isActive = true
        sessionStart = Date()

        if let minutes = minutes {
            setEnd(Date().addingTimeInterval(TimeInterval(minutes * 60)),
                   warn: continuing || minutes > warningMinimumMinutes)
        }
        if let app = appToKeep { watch(app) }
        onChange?()
    }

    /// Keeps the Mac awake with no time limit until `app` quits.
    func start(untilQuitOf app: NSRunningApplication) {
        start(minutes: nil)
        guard isActive else { return }
        watch(app)
        // It may have quit just before the observer was in place.
        if app.isTerminated { watchedAppQuit() }
    }

    private func watch(_ app: NSRunningApplication) {
        watchedApp = app
        quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let quit = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if quit?.processIdentifier == app.processIdentifier { self?.watchedAppQuit() }
        }
    }

    private func watchedAppQuit() {
        guard let name = watchedAppName else { return }
        stop()
        onWatchedAppQuit?(name)
    }

    /// Moves the end of the current timed session later, without restarting it.
    func extend(minutes: Int) {
        guard isActive, let end = endDate else { return }
        setEnd(end.addingTimeInterval(TimeInterval(minutes * 60)), warn: true)
        onChange?()
    }

    private func setEnd(_ end: Date, warn: Bool) {
        endDate = end
        endTimer?.invalidate()
        endTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            self?.stop()
            self?.onTimerFinished?()
        }
        onWarningChange?(nil)
        if warn, end.timeIntervalSinceNow > warningLead {
            onWarningChange?(end.addingTimeInterval(-warningLead))
        }
    }

    func stop() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        UsageLog.add(seconds: liveSessionSeconds)   // save the finished session into the daily log
        isActive = false
        sessionStart = nil
        endDate = nil
        endTimer?.invalidate()
        endTimer = nil
        if let observer = quitObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        quitObserver = nil
        watchedApp = nil
        onWarningChange?(nil)
        onChange?()
    }

    /// Minutes left on a timed session, rounded up. nil if there is no time limit.
    var minutesLeft: Int? {
        guard isActive, let end = endDate else { return nil }
        return max(0, Int((end.timeIntervalSinceNow / 60).rounded(.up)))
    }
}
