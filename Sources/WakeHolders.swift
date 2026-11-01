import Cocoa
import IOKit.pwr_mgt

/// Lists the other apps and processes that are preventing idle sleep right now, using the public IOKit API.
enum WakeHolders {
    struct Entry {
        let title: String
        let reason: String?   // what the processes declared, not translated. nil if they gave no reason.
    }

    /// Names left out of the list.
    /// powerd is macOS itself: it holds an assertion whenever the display is on, so it would always be listed
    /// and tells the user nothing about what is keeping the Mac awake.
    /// useractivityd appears and disappears on its own, so the count would change with nothing the user did.
    private static let ignoredProcesses: Set<String> = ["powerd", "useractivityd"]

    /// System processes with a name people can recognize: process name to the key of the text to show.
    /// The texts live in Localizable.strings. A process not listed here is shown with its own name.
    private static let friendlyNames: [String: String] = [
        "coreaudiod": "holders.name.coreaudiod",
        "sharingd": "holders.name.sharingd",
        "caffeinate": "holders.name.caffeinate"
    ]

    static func entries() -> [Entry] {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let byProcess = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }

        // Grouped by name because several processes can share one, for example helpers of the same app.
        var reasonsByName: [String: Set<String>] = [:]
        for (pid, assertions) in byProcess {
            let preventing = assertions.filter(isPreventingSleep)
            guard !preventing.isEmpty, let name = name(ofProcess: pid.int32Value),
                  !ignoredProcesses.contains(name) else { continue }
            reasonsByName[name, default: []].formUnion(preventing.compactMap(reason))
        }

        return reasonsByName
            .map { name, reasons in
                Entry(title: friendlyNames[name].map { L($0) } ?? name,
                      reason: reasons.isEmpty ? nil : reasons.sorted().joined(separator: "\n"))
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The reason the process declared. nil if it is empty.
    private static func reason(of assertion: [String: Any]) -> String? {
        guard let text = (assertion[kIOPMAssertionNameKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func isPreventingSleep(_ assertion: [String: Any]) -> Bool {
        let type = assertion[kIOPMAssertionTypeKey] as? String
        return (type == kIOPMAssertionTypePreventUserIdleSystemSleep
                || type == kIOPMAssertionTypePreventUserIdleDisplaySleep)
            && assertion[kIOPMAssertionLevelKey] as? Int != kIOPMAssertionLevelOff
    }

    /// App name when there is one, otherwise the process name. Returns nil for Tazza itself.
    private static func name(ofProcess pid: pid_t) -> String? {
        if pid == getpid() { return nil }
        if let app = NSRunningApplication(processIdentifier: pid) {
            if app.bundleIdentifier == Bundle.main.bundleIdentifier { return nil }
            if let name = app.localizedName { return name }
        }
        var buffer = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &buffer, UInt32(buffer.count)) > 0 { return String(cString: buffer) }
        // proc_name is refused for processes of other users, such as powerd. sysctl allows them, but cuts long names.
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var query = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        if sysctl(&query, UInt32(query.count), &info, &size, nil, 0) == 0, size > 0 {
            return withUnsafeBytes(of: &info.kp_proc.p_comm) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        }
        return "pid \(pid)"
    }
}
