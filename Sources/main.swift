import Cocoa

// Entry point. The app has no Dock icon and no main window: it lives in the menu bar only.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
