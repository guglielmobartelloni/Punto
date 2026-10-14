# Developing Punto

[← Back to the README](../README.md)

Run commands from the project root. The build uses Apple Command Line Tools; full Xcode is not required.

## Architecture

| File | Responsibility |
| :--- | :--- |
| `UI.swift` | SwiftUI settings, themes, search, and filters |
| `LauncherUI.swift` | Compact directional overlay |
| `UIController.h` | Interface between SwiftUI and the Objective-C runtime |
| `main.m` | Lifecycle, preferences, app launching, and controller routing |
| `input.c` | HID input, cursor, clicks, touchpad, and scrolling |
| `keyboard.c` | Held shortcuts and shared-key reference counts |
| `longpress.c` | Tap versus long-press state machine |
| `launcher.c` | Directional selection and two-slot cycling |
| `navigation.c` | Geometric directional scoring, independent of Accessibility |
| `stick.c` | Left-stick direction hysteresis, repeat timing, and recenter safety |
| `UINavigation.m` | Asynchronous AX discovery, safe native actions, and non-activating selection overlay |
| `ShortcutRecorder.m` | Shortcut recording and preference migration |
| `scripts/generate-brand-icon.swift` | macOS icon generation |

The HID filter recognizes the standard Sony DualSense: **VID 054c / PID 0ce6**. Input is read non-exclusively. Pause Punto while playing a game to avoid simultaneous input.

## Local code signing

The repository’s build is configured for the **PadMac Local Development** certificate in the development Mac’s keychain. This is a legacy certificate name, not the application name. Neither the certificate nor its private key is included in the repository.

On another Mac:

1. Create or import a local identity suitable for code signing into your keychain.
2. List available identities:

   ```sh
   security find-identity -v -p codesigning
   ```

3. Update `SIGN_IDENTITY` in the `Makefile` with your certificate name and the `certificate leaf = H"…"` requirement with its fingerprint.
4. Build and verify:

   ```sh
   make
   codesign --verify --strict build/Punto.app
   codesign -d -r- build/Punto.app
   ```

Keep the **certificate, bundle ID, and signing requirement stable** between builds. Changing the certificate, replacing an ad-hoc signature, or changing the bundle path may require removing and adding the app again in Accessibility settings.

Local signing does not replace Developer ID signing and notarization for distribution to other users.

### Application identity

| Component | Value |
| :--- | :--- |
| Display name | Punto |
| Bundle | `build/Punto.app` |
| Executable | `Punto` |
| Bundle ID | `local.padmac.controller` |

The interface, dialogs, and menu-bar commands use English. Legacy shortcut display labels and theme names are translated without changing saved keycodes, modifiers, or the selected theme.

The original bundle ID preserves the preferences domain. Its internal name and the certificate name are retained for compatibility; the application itself is named Punto.

When upgrading from the old bundle, replace the old Dock shortcut with `Punto.app`. If Accessibility authorization stops working, remove the old entry and add the new bundle.

## Input behavior

### Mouse and scrolling

- Cursor updates at **120 Hz**, with progressive acceleration and a radial deadzone.
- R1 changes the right stick from cursor movement to scrolling. The touchpad continues to move the cursor.
- Continuous pixel-based scrolling accumulates fractional deltas so slow movement is not lost.
- Scroll sensitivity: **100–3000 px/s**, initially **900**, independent of cursor speed.
- Relative touchpad movement uses a fixed sensitivity of **0.8 points/unit**. USB `0x01` and full Bluetooth `0x31` reports are decoded.
- Simplified Bluetooth reports do not include touchpad data.

### Shortcuts

- A single key with modifiers, or a modifier-only chord—not macros or sequences.
- Modifier-only combinations are reproduced using `flagsChanged` events.
- Chords remain active until the controller button is released.
- Reference counts prevent keys shared by several buttons from being released prematurely.
- Keycodes are physical: changing the keyboard layout may change the resulting character.
- Return and Escape can be recorded. Use the dialog buttons to save or cancel.

### Taps and long presses

- Without Hold: immediate key down, followed by key up on controller release.
- With Hold: a tap below **0.45 seconds** runs the primary action on release. Beyond the threshold, only the long-press chord is held until release.
- Assigning Hold to R2/L2 replaces normal dragging with this tap/hold behavior.

### Launcher

Configuration mirrors the overlay’s directional cross: Up/Down slots stack vertically, Left/Right slots sit horizontally, and slot 1 is always nearest the empty center. Each tile retains its choose/change/remove menu and displays its slot number.

- Two slots per direction, saved as application paths.
- A D-pad direction or left-stick tilt selects the first available app. It opens **500 ms after the last selection**, without confirmation.
- Pressing the same direction again while the overlay is visible cycles between occupied slots.
- Opposite input from an outer slot first steps inward on the same arm, if its inner slot is occupied. Another opposite input crosses to the opposite arm. Perpendicular input selects the new arm’s first available app; empty inner slots are skipped.
- The overlay closes **1.2 seconds** after the last direction press. A later press starts from the first slot again.
- There is no animated countdown border. On launch dispatch, one 280 ms background illumination pulse and a maximum 4.5% scale increase provide feedback. This indicates the opening request, not successful app readiness. Reduce Motion disables scaling. Selection updates are immediate, without implicit material transitions. One stable 60 Hz timeline runs only while the overlay is visible; the panel is centered and ordered front only on initial creation, never on selection changes; changing selection or closing the overlay resets feedback timestamps.
- Changing selection restarts the 500 ms deadline and replaces the pending app. ○ cancels pending launch and dismisses feedback; it does not close an app already opened. Pause, disconnect, permission loss, mode changes, and overlay closure also cancel pending launch. The deadline is checked after stick navigation in the main tick, so a new selection takes precedence over an expiring launch.
- The non-activating panel is at most **368 × 368 points**, with eight 64-point square tiles arranged by direction. Up/down pairs are stacked vertically; left/right pairs are horizontal. The four arms align on a regular grid around a 64-point empty center, with 6-point gaps between cells. The horizontal center gap includes the two adjacent gaps (76 points total). Background material is applied to each tile, not to the whole panel, so the center and corners remain transparent. Slot 1 is always nearest the center and slot 2 extends outward: visual order is reversed for Up and Left, without changing saved assignments or launch order. There is no center icon, header, footer, or instructional text; the selected tile has a coral border. Direction and slot labels remain available to Accessibility. It does not steal focus or add a Dock icon on its own.
- Other buttons are consumed and cursor movement is suppressed while the overlay is visible.

Apps previously assigned to D-pad buttons are migrated into the first slot. Previous D-pad and R1 shortcut/Hold assignments remain stored, but are not executed because these inputs now have reserved roles.

### UI navigation (experimental)

Select **Navigation → UI navigation**, or press **Select / Create** (the small button to the left of the touchpad) while controller input is enabled. Mode selection persists in `uiNavigation`; controller input still starts paused.

- The D-pad or left stick selects accessible controls in the frontmost app’s focused window, modal sheet, or focused menu. The first press selects the focused control if available, otherwise the first discovered control.
- Subsequent presses rank element centers in a directional cone, favoring the same row or column. At a boundary the selection remains in place; it does not wrap.
- Disabled, hidden, off-screen, and out-of-viewport controls are excluded when the provider supplies the necessary information.
- **✕** invokes `AXPress`, `AXConfirm`, or `AXPick`; editable fields use the settable `AXFocused` attribute. No coordinate-click fallback is used.
- **○** requests `AXCancel`. If unsupported, Escape is emitted through the shared-key reference-counting engine.
- The coral border is a non-activating, click-through panel. Mode and failure feedback use a short-lived, non-activating badge.
- Tree discovery runs on a serial background queue, capped at 2,000 elements and a 300 ms traversal budget, with 25 ms per-attribute messaging timeouts. Native actions have a separate 500 ms timeout. A single remote call may slightly exceed the traversal budget.
- A lighter 250 ms poll tracks the selection. Activation rescans and revalidates the element, app, and window; stale elements are rejected rather than blindly clicked. Selection is retained if the control remains visible after activation. Some providers return an error even after dispatching an action; ambiguous results are shown as “Action requested” and are never retried automatically.
- An eight-command queue preserves rapid presses. App/window changes discard queued commands. Generation checks invalidate pending actions on pause, disconnect, permission loss, or mode changes.
- Switching modes releases held mouse buttons/keys and cancels long presses. Existing launcher, Select/Create, ✕, and ○ assignments remain stored. Select/Create is reserved; touchpad click is customizable; ✕ and ○ regain normal assignments outside navigation mode.
- Left-stick HID X/Y axes are independent of the right stick’s Z/Rz axes. Navigation engages at 55% deflection, recenters at 30%, and uses sector hysteresis to suppress diagonal jitter.
- In UI navigation, the left stick repeats after 380 ms, then every 180 ms. Analog repeats are coalesced to one pending move and canceled when the stick recenters, without discarding digital presses. In the launcher, each tilt opens an app once; another tilt requires recentering.
- Pausing, disconnecting, changing modes, and entering the launcher reset the stick state; recentering is required before a new navigation gesture. L3’s click assignment remains customizable.
- The right stick, touchpad movement, R1 scrolling, and trigger clicks remain available as a mouse fallback.

This is not universal semantic navigation: app Accessibility providers determine coverage, grouping, visibility, and action support. Custom canvases and some browser content are incomplete. Text entry, complex slider editing, virtualized lists, and automatic scrolling to off-screen controls are not implemented. No window content or discovered control labels are logged or persisted by the runtime.

### Safety and preferences

Punto starts paused. Pausing, disconnecting, losing Accessibility permission, and normal application exit release held synthetic keys. Changing an assignment pauses input before opening a picker. Opening the launcher releases held clicks/shortcuts and cancels pending long presses.

Preferences use `NSUserDefaults`. Applications are stored by path and must be selected again if moved or removed.

## Tests

```sh
make test
make test-dock
make test-launcher-ui
make test-navigation-ui
```

| Suite | Coverage |
| :--- | :--- |
| `buttons` | Dispatch, press deduplication, and pausing |
| `shortcuts` | Recording, special keys, modifiers, and migration |
| `keyboard` | Held chords, shared keys, and safety releases |
| `longpress` | Thresholds, tap/hold exclusivity, and cancellation |
| `launcher` | Directions, two slots, empty slots, and reset |
| `scroll` | Directions, sensitivity, bounds, fractional deltas, and cursor restoration |
| `dock` | Showing the Dock icon with settings, closing, and reopening |
| `launcher-ui` | Delayed latest-selection launching, deadline reset, one-shot delivery, cancellation safety, and overlay preview |
| `navigation` | Direction scoring, row/column preference, boundaries, invalid rectangles, and multiple-display coordinates |
| `navigation-ui` | D-pad/left-stick routing, coalesced repeats, mode switching, activation/back, shortcut isolation, pause, and preserved assignments |
| `stick` | Four directions, thresholds, diagonal hysteresis, repeat timing, single-shot launching, and recenter safety |

UI suites require a macOS graphical session. The launcher test uses isolated volatile preferences and intercepts app launches: **it does not change assignments or open demo applications**.

### Optional live Accessibility test

```sh
make test-navigation-ax
```

This builds and opens `build/NavigationAXTest.app`, signed with the local certificate and a separate bundle ID (`local.punto.navigation.fixture`). Grant **that fixture** Accessibility permission and rerun if it reports a permission failure. LaunchServices is used so macOS evaluates the fixture’s authorization rather than the invoking terminal’s. The target exits unsuccessfully if it does not obtain a PASS result.

The fixture inspects and acts **only on its own window**, even if another app becomes active. It verifies real AX discovery, disabled-control exclusion, non-activating highlighting, `AXPress`, editable-field focus, canceled pending activation, and stale-window rejection. Results are written to `build/ax-test-result.txt`; fixture-only diagnostics are in the matching `.log` file. It does not load or modify Punto’s preferences.

## Manual verification

- [ ] USB and Bluetooth connection/disconnection.
- [ ] Cursor direction, deadzone, and multiple displays.
- [ ] Touchpad tracking, finger lift, and repositioning.
- [ ] R2/L2 clicks and dragging, including simultaneous presses.
- [ ] R1 scrolling in all directions, sensitivity changes, and cursor restoration.
- [ ] Held shortcuts and modifier-only ⌥⇧, including a voice assistant.
- [ ] Tap/hold behavior and pausing before/after the threshold.
- [ ] Launcher selection delay, second slot, deadline reset, ○ cancellation, and timeout.
- [ ] No normal ✕/○ shortcut while the overlay is visible.
- [ ] Select/Create switches launcher/navigation without running its saved assignment; touchpad click runs its configured action.
- [ ] Left-stick directions, held repeat, recentering, and independent right-stick mouse control.
- [ ] Launcher opens once per tilt and does not cycle repeatedly while held.
- [ ] Navigation selects controls spatially and activates them in the intended target apps.
- [ ] The border does not take focus, intercept clicks, or appear in the Dock.
- [ ] App/window changes, pause, disconnect, and permission loss clear the selection.
- [ ] Unsupported controls produce feedback rather than a coordinate click.
- [ ] Preferences survive an application restart.
- [ ] Canceling a picker preserves its previous assignment.

Automated tests do not replace testing with a real controller in the target applications.

## Screenshots

Capture only the application’s own window content, without taking a desktop screenshot:

```sh
# Quit the app first, then launch it with preview arguments.
open build/Punto.app --args \
  --ui-page mouse --ui-dark \
  --ui-preview "$PWD/build/ui-mouse.png"
```

Available pages: `buttons`, `launcher`, `navigation`, `mouse`, `permissions`. `--ui-group Shoulders` filters the shoulder buttons. Omit `--ui-dark` for a light preview. These options do not change assignments.

`make test-launcher-ui` creates `build/ui-launcher.png` during countdown and `build/ui-launcher-pulse.png` during an intercepted launch pulse, using demo applications. README screenshots live in `docs/screenshots/`.

## Current limitations

- One controller at a time; DualSense Edge is not supported.
- No per-application profiles, automatic startup, or notarized release package.
- PS and Mute depend on the events exposed by macOS and the controller firmware.
- System-intercepted combinations and some media keys may not be captured or reproducible.
