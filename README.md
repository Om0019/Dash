# Dash (iOS)

A small SwiftUI companion app plus a WidgetKit extension that brings the
"Orlando's Dashboard" web page to the iOS Home Screen as widgets.

## Opening the project

Open `Dash.xcodeproj` in Xcode 15+ and run the `Dash`
scheme on an iOS 17+ simulator or device.

## What's included

- **Dash** — the container app. It requests Calendar access,
  syncs iOS/Google events via EventKit, and matches the original
  `index.html` dashboard's layout, glass-card styling, colors, and copy
  (header + last-synced timestamp, 4 stat tiles, Assignments, Face Care,
  Craft folders with deep links into the Craft app, Recent Craft activity).
  Cards stack in one column on iPhone-width screens instead of the web
  version's fixed 2×2 grid, since that grid was sized for a much wider
  viewport.
- **OrlandoWidgets** — a WidgetKit extension with four widgets, all styled
  as translucent, blurred "glass" cards (`.ultraThinMaterial` +
  `containerBackground`).

  **Liquid Glass is a Home Screen setting, not a code switch.** On iOS 26,
  long-press the Home Screen → **Edit → Customize → Clear**, and the system
  strips the widget's background and renders it as true Liquid Glass,
  refracting the wallpaper alongside the app icons. The only thing the
  widget must do is not opt out — `containerBackgroundRemovable` defaults
  to true, so leave it alone. In Default/Dark modes the background below
  is what shows, which is why it paints the app's palette.

  Two approaches were tried and do **not** work: `.glassEffect(...)` inside
  `containerBackground` renders nothing (widgets are snapshotted out of
  process; glass is a live compositing effect), and supplying `Color.clear`
  doesn't reveal glass either — it just yields the system's opaque default
  platter, which is white in light appearance and hides white text.

  **Widgets can't be pinned to a color scheme.** The app forces dark via
  `UIUserInterfaceStyle`, but that doesn't reach the extension; setting the
  same key on the extension's own Info.plist does nothing; and
  `.environment(\.colorScheme, .dark)` gets reapplied by WidgetKit at
  render time. All three were tried and verified not to work — widgets
  follow the Home Screen appearance.

  Rather than adapt to an appearance we can't control, the background paints
  the app's palette over the material, which makes the surface
  deterministically dark in *either* appearance — so widget text can safely
  stay light (`.foregroundStyle(.white)` at the root, plus the palette's
  muted/secondary tones). Getting here took two wrong turns worth not
  repeating: hard-coding white over the *adaptive* material made the stat
  numbers invisible on a light Home Screen, and compensating with a flat
  gray scrim turned the glass to mud — it's the color in the tint that
  makes it read as glass. Verified in both appearances via
  `xcrun simctl ui <udid> appearance dark|light`.

  The widgets are:
  - **Dashboard Stats** (small) — due today / due this week / Craft docs / open tasks.
  - **Assignments** (medium/large) — upcoming calendar events, or the "nothing due" empty state.
  - **Face Care Routine** (medium) — today's AM/PM skincare steps.
  - **Craft Folders** (medium/large) — your class folders in Craft.
- **Shared/AppGroup.swift** — the App Group storage layer and
  `CalendarSnapshot` / `CraftSnapshot` models shared by both targets.
- **Shared/DashboardData.swift** — reads the live calendar snapshot and the
  bundled Craft snapshot, mirroring the content of the original
  `index.html` dashboard.
- **Dash/CalendarService.swift** — the EventKit sync that
  populates the calendar-driven widgets.
- **Dash/CraftService.swift** — the live Craft Connect API sync
  that populates the Craft folders/docs widgets.
- **Dash/DashboardStyle.swift** — the shared visual language
  (`AmbientGlow` background, `glassSurface()` card treatment,
  `AccentButtonStyle`, section/row primitives). Both the dashboard and the
  Connections screen build from these, so styling changes happen in one
  place.

  If the cards ever look solid again, the lever is the material's opacity
  in `glassSurface()` / `glassCapsule()`, not the background. Dark-mode
  `.ultraThinMaterial` is much heavier than its name suggests and reads as
  a flat gray card at full strength, so both are drawn at reduced opacity
  to let the backdrop through while keeping the blur. `AmbientGlow` is
  meant to stay subtle — it's a backdrop, not the subject.

## Adding widgets to the Home Screen

Build and run the app once on a device/simulator, then long-press an empty
area of the Home Screen → tap **+** in the top corner → search for
"Dash" → pick a widget size → **Add Widget**.

## One-time Xcode setup: App Group

The app and widget extension share calendar data through an App Group
container. This has to be wired up once in Xcode (it can't be done from
files alone):

1. Select the **Dash** target → **Signing & Capabilities** → **+
   Capability** → **App Groups**. Add (or check) the group
   `group.com.orlandodash.shared`.
2. Repeat for the **OrlandoWidgets** target, using the same group ID.
3. Xcode will generate/link `.entitlements` files for each target — this
   repo already has placeholder ones
   (`Dash/Dash.entitlements`,
   `OrlandoWidgets/OrlandoWidgets.entitlements`) with the matching group ID,
   so Xcode should just pick them up.

Without this step, calendar sync will silently no-op for the widgets (the
app can still read its own data, but the widget process reads from a
different sandbox).

## Connections screen

Tap the floating gear button in the app's bottom-left corner to open
**Connections**. It's presented as an overlay rather than a navigation
push, so the button stays put and morphs into a back arrow to return:

- **Calendar** — connection status, a button to grant access, a link straight
  to iOS Settings for adding a Google account, and a per-calendar toggle
  list (grouped by account/source) so you can choose exactly which
  calendars feed the dashboard instead of syncing everything. Selections
  persist and re-sync immediately.
- **Craft** — on first use, a field to paste your Craft Connect link (from
  Craft: **Space Settings → Connect API → Create/Copy link**); once saved,
  connection status, a manual **Sync now** button, a last-synced timestamp,
  and a **Change Craft link** action to swap it out later.

## Calendar (iOS + Google)

The app uses `EventKit` (`Dash/CalendarService.swift`) to read
every calendar source the system knows about — there's no separate Google
integration to build:

1. On the phone: **Settings → Calendar → Accounts → Add Account → Google**,
   sign in, and make sure the Google calendars you want are toggled on.
2. Open Dash and tap **Connect Calendar** to grant access.
   Google's events show up in the same sync as iOS/Apple ones since they're
   now part of the same system calendar store.
3. The app syncs on launch and writes a `CalendarSnapshot` into the App
   Group container; widgets read it live and refresh once a day (or
   immediately after a manual sync, via `WidgetCenter.reloadAllTimelines()`).

If you'd rather authenticate with Google directly inside the app (OAuth,
`GoogleSignIn` SDK, Calendar REST API) instead of relying on the system
calendar merge, that's a bigger lift — a Google Cloud project, OAuth client,
consent screen, and token refresh — and isn't wired up here.

## Craft docs

`Dash/CraftService.swift` syncs live from Craft's Connect REST
API (`https://connect.craft.do/links/.../api/v1` — the same API backing
Craft's MCP connector), on app launch and via the **Sync Craft** button on
the "Craft docs" card. It reads `/folders`, `/documents`, and `/tasks` and
writes a `CraftSnapshot` into the App Group container, same as calendar
sync. `Shared/DashboardData.swift` still ships a `bundledCraftSnapshot` as
a fallback for the very first launch, before any sync has run.

**Known API quirk:** `GET /documents?folder=<id>` does not actually filter
by folder — verified live, it returns the same full document list
regardless of which id is passed. `CraftService` relies only on
`/folders` (for names/doc counts) and `GET /documents?location=unsorted`
(for the Recent Activity list), both of which are accurate; don't
reintroduce per-folder document fetching without re-verifying that filter
works.

**Security note:** the Craft Connect link carries an account-scoped access
token — anyone who has it gets full read/write access to the Craft space.
It is never hardcoded in source or committed to this repo; instead, enter it
once in the app's **Connections → Craft** screen (see
[Connections screen](#connections-screen) below), and it's stored only in
the local App Group container on your device. If it's ever compromised,
revoke/regenerate the Connect link from Craft and re-enter the new one in
the app.
