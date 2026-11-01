# Tazza ☕

A tiny, free, open source menu bar app that keeps your Mac awake, with a few useful stats.
No Dock icon, no window, no tracking. Tazza itself makes no network connections: the only links are two menu items
that open in your browser when you click them.

Tazza uses the same macOS power assertion as `caffeinate`: no sudo, no daemon, no kernel extension.
Quit the app and the assertion is released. It also runs two macOS tools locally: `system_profiler` to read battery
health and `pmset` to turn off the screen.

<!-- Screenshots: add the two images here when they are ready. -->

## Features

- One click to keep your Mac awake: no time limit, 30 min, 1 h, 2 h or 4 h
- Keep it awake until an app you pick quits
- Option to keep the display on too (like `caffeinate -d`)
- Turns itself off when the battery drops below 20% and the Mac is unplugged
- Notifies you when a timer ends, when the app you picked quits, or when the low battery rule turns it off
- Warns you 5 minutes before a timer ends, with buttons to add 30 minutes or turn off now
- Turn off the screen now, without ending a running session
- Battery stats: level, time remaining, health, charge cycles, temperature
- Optional battery percentage next to the cup in the menu bar
- Local usage log: time kept awake this session, today and in the last 7 days (stored only on your Mac)
- System info: uptime, thermal state, and whether Low Power Mode is on
- See which other apps and processes are preventing idle sleep, with the reason they declare in a tooltip
  (`powerd` and `useractivityd` are left out)
- Launch at login option
- English by default, Italian included. Language follows your macOS language

## Limits you should know

- Like `caffeinate -i`, Tazza does **not** stop a MacBook from sleeping when you close the lid. Whether it stays awake with an external display connected is up to macOS, not Tazza.
- Battery cycles and temperature come from the system battery registry. Battery health comes from `system_profiler`, read each time the menu opens through a field Apple does not document. If that fails, Tazza shows an estimate from the registry, which can differ by a few points from what macOS shows. These values are read only and can be missing on some Macs.
- Notifications need your permission, which macOS asks for the first time you start a session. If you refuse, Tazza works without them. You can change this in System Settings, Notifications: while they are off, the menu shows an item that opens that page. The two buttons on the warning may appear only when you move the pointer over the banner.
- The app is signed ad hoc, not with an Apple Developer ID, and it is not notarized. See below for what this means when you open it.
- "Launch at login" may not work unless the app is in `/Applications`.
- On a crowded menu bar, macOS can hide the icon, for example behind the notch.

## Compatibility

Built for macOS 13 or later, tested on macOS 26 with Apple Silicon; Intel and macOS 13 not tested.

## Download

Download `Tazza-1.0.1.dmg` from the Releases page of https://github.com/nsantullo/Tazza, open it and drag Tazza into Applications.

macOS may block the app the first time you open it, because it is signed ad hoc and not notarized.
Try to open it, then go to System Settings, Privacy & Security, and choose Open Anyway.

## Build

Requirements: macOS 13 or later and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/nsantullo/Tazza.git
cd Tazza
./build.sh
open build/Tazza.app
```

To install: `cp -R build/Tazza.app /Applications/`.

To create the DMG, run `./build.sh` first, then `./make-dmg.sh`. The result is `build/Tazza-<version>.dmg`.
`./build.sh` deletes the build folder, DMG included, so always run them in this order.

Because of the ad hoc signature, macOS may block the app the first time you open it, especially if you downloaded it.
On recent versions of macOS, try to open it, then go to System Settings, Privacy & Security, and choose Open Anyway.

## Customize

Edit the top of `build.sh` to set your GitHub username, donation link and bundle identifier.
`build.sh` turns `Resources/AppIcon.png`, a 1024x1024 PNG, into the app icon. The menu bar icon is drawn in code, in `Sources/MenuBarIcon.swift`.

## Development

To see the warning shown before a timer ends without waiting for a real session, start the app with `--notify-test`.
It appears after 10 seconds. There is no session behind it, so its two buttons do nothing. The option is not in the menu.
It needs the notification permission: if macOS asks for it during the test, answer and start the app again.

```bash
open -n build/Tazza.app --args --notify-test
```

## Add a language

Copy `Resources/en.lproj` to `Resources/<code>.lproj` (for example `es.lproj`), translate the right side of each line,
and add the code to `CFBundleLocalizations` in `build.sh`. Pull requests are welcome.

## Support the project

Tazza is free and open source. If it is useful to you, you can support it on Ko-fi at https://ko-fi.com/nicolas92,
with the Sponsor button on GitHub, or with the "Support Tazza" item in the app menu.

## License

MIT. See `LICENSE`.
