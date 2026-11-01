import Foundation
import IOKit
import IOKit.ps

/// Snapshot of the battery state. `read()` returns nil on Macs without a battery (iMac, Mac mini...).
struct BatteryInfo {
    var percent: Int
    var onAC: Bool
    var isCharging: Bool
    var isFull: Bool
    var minutesRemaining: Int?   // time to empty, or time to full when charging
    var cycleCount: Int?
    var healthPercent: Int?      // current max capacity vs design capacity
    var temperatureC: Double?

    static func read() -> BatteryInfo? {
        // 1) Public power source API: level, charging state, time remaining.
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let percent = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let full = desc[kIOPSIsChargedKey] as? Bool ?? false

            var minutes: Int? = nil
            let timeKey = charging ? "Time to Full Charge" : "Time to Empty"
            if let m = desc[timeKey] as? Int, m > 0 { minutes = m }

            var info = BatteryInfo(percent: percent, onAC: onAC, isCharging: charging, isFull: full,
                                   minutesRemaining: minutes, cycleCount: nil, healthPercent: nil, temperatureC: nil)

            // 2) IORegistry: cycle count, health, temperature (not in the public API).
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any] {
                    info.cycleCount = dict["CycleCount"] as? Int
                    let design = dict["DesignCapacity"] as? Int ?? 0
                    // Estimate, used only if systemHealthPercent() fails: the percentage in System Settings is not
                    // in this registry. On an M2 Pro where macOS said 94%: NominalChargeCapacity 92.4%,
                    // AppleRawMaxCapacity 90.0%. NominalChargeCapacity is the closest, so it comes first.
                    // MaxCapacity is mAh on Intel but already a percentage (100) on Apple Silicon: the > 100 skips it.
                    let capacity = ["NominalChargeCapacity", "AppleRawMaxCapacity", "MaxCapacity"]
                        .lazy.compactMap { dict[$0] as? Int }.first { $0 > 100 }
                    if design > 0, let capacity = capacity {
                        info.healthPercent = min(100, Int((Double(capacity) * 100 / Double(design)).rounded()))
                    }
                    if let t = dict["Temperature"] as? Int {
                        info.temperatureC = Double(t) / 100.0
                    }
                }
                IOObjectRelease(service)
            }
            return info
        }
        return nil
    }

    /// The "Maximum Capacity" macOS itself reports, which no registry key or public API exposes.
    /// It spawns a process, so call it only when the value is shown, not from `read()`, which runs every minute.
    /// The JSON key is undocumented: returns nil if it changes or the tool is slow, and callers use `healthPercent`.
    static func systemHealthPercent() -> Int? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", "SPPowerDataType"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        guard (try? process.run()) != nil else { return nil }
        // This runs while the menu opens: never hold it up for long.
        if finished.wait(timeout: .now() + 2) == .timedOut {
            process.terminate()
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["SPPowerDataType"] as? [[String: Any]] else { return nil }
        for section in sections {
            if let health = section["sppower_battery_health_info"] as? [String: Any],
               let value = health["sppower_battery_health_maximum_capacity"] as? String,
               let percent = Int(value.replacingOccurrences(of: "%", with: "")) {
                return percent
            }
        }
        return nil
    }
}
