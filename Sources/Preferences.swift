import Foundation

/// Small wrapper around UserDefaults so the rest of the code stays readable.
enum Prefs {
    private static let defaults = UserDefaults.standard

    /// Also keep the display on (like `caffeinate -d`). Default: only prevent system sleep (`-i`).
    static var keepDisplayOn: Bool {
        get { defaults.bool(forKey: "keepDisplayOn") }
        set { defaults.set(newValue, forKey: "keepDisplayOn") }
    }

    /// Automatically stop keeping the Mac awake when the battery is low and unplugged.
    static var stopOnLowBattery: Bool {
        get { defaults.object(forKey: "stopOnLowBattery") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "stopOnLowBattery") }
    }

    /// Show the battery percentage next to the cup icon in the menu bar.
    static var showBatteryInMenuBar: Bool {
        get { defaults.bool(forKey: "showBatteryInMenuBar") }
        set { defaults.set(newValue, forKey: "showBatteryInMenuBar") }
    }

    /// Battery level (percent) under which Tazza stops when running on battery.
    static let lowBatteryThreshold = 20
}
