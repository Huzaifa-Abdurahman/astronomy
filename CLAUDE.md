# SkyGuide — Flutter build guide for Claude Code

> Read this whole file before writing code. It is the single source of truth for what to build, how it should look, and how the astronomy math must work. Build in the phase order at the end and do not skip the acceptance checks.

---

## 1. What we are building

**SkyGuide** is a Flutter app (Android + iOS) that:

1. Gets the user's **live GPS location**.
2. Lets the user **pick a star, planet, galaxy, nebula or cluster**.
3. **Calculates mathematically** (on-device, no astronomy API) where that object is in the user's sky right now (altitude/azimuth), when it **rises, peaks and sets**, and the **best dark-sky viewing window**.
4. **Points the user to it** using the phone's compass and tilt sensors.
5. Shows **live public satellites** (ISS, Tiangong, Hubble…) and their **next visible passes** from a public API.
6. Shows **nearby dark-sky public spots** on a map, a **tonight's plan** timeline with reminders, and a **profile/settings** page.
7. Has an animated cartoon mascot, **Cosmo the astronaut**, and an energetic cyan→violet "light beam" visual style.

This is a university Flutter lab project (vibe-coding / AI-assisted coding lab). Code must be clean, readable, commented where the math happens, and runnable with `flutter run` on a fresh machine.

---

## 2. Tech stack

Add packages with `flutter pub add <name>` so you get the current stable versions. Do not hand-pin old versions.

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| Location | `geolocator` (+ platform permission setup) |
| Compass heading | `flutter_compass` |
| Tilt / accelerometer | `sensors_plus` |
| HTTP | `dio` |
| Charts (altitude curve) | `fl_chart` |
| Map (no API key needed) | `flutter_map` + `latlong2` (OpenStreetMap tiles) |
| SVG (Cosmo, icons) | `flutter_svg` |
| Fonts | `google_fonts` |
| Local notifications | `flutter_local_notifications` + `timezone` |
| Local storage | `shared_preferences` |
| Env / API keys | `flutter_dotenv` |
| Date formatting | `intl` |
| Haptics | built-in `HapticFeedback` |
| Tests | `flutter_test` (built in) |

Minimum: Flutter 3.x stable, Dart 3, null-safety, Material 3.

---

## 3. Project structure

```
lib/
  main.dart
  app.dart                      # MaterialApp.router, theme, router
  core/
    theme/
      app_colors.dart           # design tokens (section 4)
      app_text.dart             # Bricolage Grotesque / DM Sans / DM Mono styles
      app_theme.dart
    widgets/
      glass_card.dart           # translucent navy card with border
      gradient_button.dart      # cyan→violet primary button
      light_beams.dart          # animated diagonal beams (section 4.4)
      hero_background.dart      # image + gradient fade + slow drift
      sky_nav_bar.dart          # 5-tab bottom nav
      status_pill.dart
      cosmo.dart                # animated mascot (section 4.5)
      twinkle_stars.dart
    router.dart
    env.dart
  features/
    onboarding/      onboarding_screen.dart
    permission/      permission_screen.dart
    home/            home_screen.dart
    explore/         explore_screen.dart, explore_controller.dart
    object_detail/   object_detail_screen.dart, altitude_chart.dart
    pointer/         pointer_screen.dart, pointer_controller.dart
    math/            math_screen.dart
    satellites/      satellites_screen.dart, satellites_repository.dart
    nearby/          nearby_screen.dart
    tonight/         tonight_screen.dart, reminders_service.dart
    profile/         profile_screen.dart
  astro/                        # PURE DART, no Flutter imports — unit-testable
    time.dart                   # Julian date, GMST, LST
    coords.dart                 # RA/Dec ↔ Alt/Az, hour angle
    rise_set.dart               # rise / transit / set, circumpolar handling
    sun.dart                    # low-precision solar position, twilight times
    planets.dart                # (Phase 6) approximate planet RA/Dec
    precession.dart             # J2000 → date (optional, small correction)
    models.dart                 # SkyObject, HorizontalPosition, VisibilityWindow
  data/
    catalog.json                # bright stars + Messier objects (section 7)
    catalog_repository.dart
    location_service.dart
    sensors_service.dart
    n2yo_api.dart
    celestrak_api.dart
assets/
  backgrounds/                  # the 11 images from skyguide-assets.zip
  cosmo/cosmo.svg
test/
  astro_test.dart               # MUST pass (section 6.8)
.env                            # N2YO_API_KEY=xxxx  (git-ignored)
```

Keep `lib/astro/` free of Flutter so it can be tested with plain `dart test` logic.

---

## 4. Design system

The UI was designed screen by screen; the design canvas is the visual reference. Match it closely.

### 4.1 Colors (`app_colors.dart`)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#070A1F` | App background (deep indigo-black) |
| `surface` | `#0E1334` at 88–94% opacity | Cards, nav bar |
| `surfaceBorder` | `#26306A` | Default card border |
| `surfaceBorderStrong` | `#2F3A7C` | Inputs, emphasized cards |
| `cyan` | `#3EE7FF` | Primary accent, live data, active tab |
| `blue` | `#7C8CFF` | Gradient middle |
| `violet` | `#A06BFF` | Secondary accent |
| `violetSoft` | `#C3A6FF` | Violet text on dark |
| `pink` | `#FF8FE0` | Nebula / favourite accent |
| `warm` | `#FFD27A` | City lights, "fair sky" tag |
| `red` | `#FF8A7A` | North marker, night-vision mode |
| `text` | `#F2F4FF` | Primary text |
| `textSoft` | `#D8DCF2` | Secondary text on images |
| `textMuted` | `#A9B1D6` | Labels, captions |
| `navInactive` | `#8E97C2` | Inactive nav items |

Primary gradient: `LinearGradient([cyan, blue @55%, violet])` left→right.
Primary button text is **dark** `#070A1F` on the gradient (better contrast than white).
Accent card fill: `cyan @22%` → `violet @22%` diagonal, border `#4FC9EA`, soft cyan glow shadow.

### 4.2 Typography (`google_fonts`)

- **Display / headings:** Bricolage Grotesque, weight 700–800, letter-spacing −0.03em. Screen titles 32–38 px, section headings 20 px.
- **Body / UI:** DM Sans, 400–600. Body 15 px, labels 13 px, captions 11–12 px.
- **Numbers (coordinates, times, degrees):** DM Mono 400–500. All numeric astronomy readouts use this.

Gradient text (e.g. "Guide", "horizon", "12°"): use `ShaderMask` with the primary gradient.

### 4.3 Shape and spacing

- Screen side padding 20. Card radius 18–24. Buttons 54 px high, radius 18. Icon buttons 44×44, radius 14.
- Glass cards: `surface` fill + 1 px border. No heavy drop shadows except the cyan glow on primary elements.
- Icons: one line-icon set, 24 grid, **stroke 1.75, round caps and joins**. Use `lucide_icons` or `phosphor_flutter` (regular weight) so every icon matches. Do not mix filled and outline styles.
- Touch targets ≥ 44 px. Text contrast ≥ 4.5:1.

### 4.4 Motion (the "energy")

All animations must be disabled when `MediaQuery.of(context).disableAnimations` is true.

| Effect | Spec |
|---|---|
| **Light beams** | Two diagonal bands rotated −20…−30°. One wide soft band (90–110 px tall, cyan@18%→violet@14%, blurred 10 px). One 2 px bright line (cyan→violet with a cyan glow). Both slide ±24 px horizontally and pulse opacity 0.25↔1 over 5 s, offset 2.5 s. Use `AnimationController` + `Transform`. |
| **Background drift** | Hero images slowly scale 1.04↔1.10 and shift −6 px over 18–22 s (Ken Burns). |
| **Twinkle** | Small star dots fade 0.2↔1 over 3 s, staggered. |
| **Shooting star** | On onboarding: a short line streaks diagonally every ~7 s. |
| **Pulse rings** | Live markers (ISS, user location, target ring) expand 0.6→2× and fade over 2 s. |
| **Chart draw-in** | Altitude curve draws left→right in 2.4 s on first show. |
| **Orbit** | Satellite icon travels along a dashed arc over the satellites hero (10 s loop). |
| **Map pins** | Bob up/down 4 px, staggered. |
| **Haptics** | Light haptic when the pointer is within 3° of the target; medium when within 1°. |

### 4.5 Cosmo the astronaut (mascot)

`assets/cosmo/cosmo.svg` is the base drawing (white suit, dark visor with cyan eyes, cyan chest panel, violet antenna tip). Build `Cosmo` as a widget with poses:

- `wave` — right arm rotates 0↔22° about the shoulder (1.6 s loop)
- `telescope` — holds a telescope that sways ±8° (3 s)
- `board` — holds a cyan "∑" board that taps −14° (1.2 s)
- `phone` — holds a glowing phone (onboarding)
- All poses: whole body floats ±7 px with ±4° rotation (4 s), antenna blinks (2 s).

Easiest implementation: draw Cosmo with `CustomPainter` (rects/circles match the SVG), so arms can be animated independently. Alternative: Rive. Cosmo appears on Permission, Pointer (centre of compass), Math, Profile (avatar) and empty/error states.

### 4.6 Background images

From `skyguide-assets.zip` → `assets/backgrounds/`:

| File | Screen |
|---|---|
| `bg-onboard.jpg` | Onboarding (full screen) |
| `bg-permission.jpg` | Location permission (full screen) |
| `bg-home.jpg` | Home hero (flip horizontally so the person sits on the right) |
| `bg-explore.jpg` | Explore hero |
| `bg-detail.jpg` | Object detail hero; also the M31 thumbnail |
| `bg-pointer.jpg` | Point-to-sky (full screen) |
| `bg-math.jpg` | Math hero |
| `bg-sat.jpg` | Satellites hero |
| `bg-nearby.jpg` | Nearby spots hero |
| `bg-tonight.jpg` | Tonight's plan hero |
| `bg-profile.jpg` | Profile hero |

Every hero image fades into `bg` with a vertical gradient (transparent → `#070A1F`) so text below stays readable.

---

## 5. Screens

Bottom navigation (5 tabs): **Home · Explore · Map · Satellites · Profile**. Active tab is cyan with a small glowing dot. Math, Object detail, Pointer and Tonight are pushed routes with a back button.

| # | Route | Screen | Key content |
|---|---|---|---|
| 1 | `/onboarding` | Onboarding | Full-screen bg, SkyGuide logo (4-point sparkle + "Sky**Guide**" gradient), 4 feature icons (Live location, Sky objects, When to look, Satellites), headline "Explore beyond your **horizon**", page dots, **Get started** button. Show only on first launch. |
| 2 | `/permission` | Location permission | Glass bottom sheet with pulsing pin, title "Where are you looking from?", 3 benefit checks, **Allow while using the app** (requests permission) and **Enter a city instead** (manual lat/lon or city search). Cosmo waves. |
| 3 | `/home` | Home | Menu button, location chip ("Islamabad ▾"), "Good evening, Explorer ✦", search bar, 4 category tiles (Stars, Planets, Galaxies, Nebulae), **Tonight's highlight** card (best object now: name, type, peak time, dark window, current az/alt, **Point me to it**), two quick tiles: Tonight's plan, Dark-sky spots. Greeting changes by local time. |
| 4 | `/explore` | Explore | Title, search (name / Messier / NGC), filter chips (Visible now, Stars, Planets, Galaxies, Nebulae), list with thumbnail, catalog id, RA, magnitude, and **live altitude + compass direction** or a "Rises later" pill. Sorted by altitude when "Visible now" is on. |
| 5 | `/object/:id` | Object detail | Hero image, favourite button, type line, name, **Altitude now** and **Azimuth now** tiles, **altitude-tonight chart** (noon→08:00, shaded dark window, "now" marker), Rises / Best (peak) / Sets tiles with directions, **Point me to it** and **Math** buttons. Recalculate every 10 s. |
| 6 | `/object/:id/point` | Point-to-sky | Full-screen bg, "Turn right/left N°" big gradient number, compass ring (N/E/S/W rotate with heading, arrow to target azimuth, Cosmo in centre), tilt bar (current pitch vs target altitude), readouts: phone heading, target az, target alt. Red night-vision toggle. Haptics when aligned. |
| 7 | `/object/:id/math` | Math | Inputs φ, λ, α, δ, then the 7 calculation steps with **live numbers** (section 6). Highlight the altitude and azimuth results. |
| 8 | `/satellites` | Satellites | Earth hero with animated orbit, LIVE badge, ISS card (NORAD id, altitude km, speed km/s, next pass time, path text "Appears WSW, max 52°, gone NE"), list of other satellites, **Alert me 10 min before**. |
| 9 | `/nearby` | Map | `flutter_map` with dark tiles, user location pulse, pins for public dark-sky spots, list cards (photo, name, note, distance, sky-quality tag). Recentre button. |
| 10 | `/tonight` | Tonight's plan | Date strip (5 days), vertical timeline: sunset, astronomical darkness, NOW marker, object peaks, satellite passes; each future event has a reminder switch. |
| 11 | `/profile` | Profile & settings | Cosmo avatar with rotating gradient ring, saved objects, settings: Location (Live GPS / manual), Red night-vision mode, Pass and peak alerts, Data sources (N2YO · CelesTrak), About. |

States to handle on every data screen: **loading** (shimmer cards), **no location** (Cosmo + "Enable location" button), **no internet** (satellites only; astronomy still works offline), **object below horizon all night** ("Not visible from your location tonight"), **circumpolar** ("Never sets from here").

---

## 6. Astronomy math (the core of the lab)

All angles in degrees unless noted; convert with `rad = deg * pi / 180`. Normalise angles with `((x % 360) + 360) % 360`. Use `DateTime.now().toUtc()` for all calculations and convert to local only for display.

### 6.1 Julian Date

```
JD = unixMillis / 86400000.0 + 2440587.5
```

### 6.2 Days since J2000

```
D = JD − 2451545.0
```

### 6.3 Greenwich Mean Sidereal Time

```
GMST = 280.46061837 + 360.98564736629 · D        (normalise 0–360)
```

### 6.4 Local Sidereal Time and hour angle

```
LST = GMST + λ           (λ = longitude, east positive)
H   = LST − α            (α = right ascension in degrees = hours × 15)
normalise H to −180…+180
```

### 6.5 Altitude and azimuth

```
sin(alt) = sin δ · sin φ + cos δ · cos φ · cos H
cos(A)   = (sin δ − sin(alt) · sin φ) / (cos(alt) · cos φ)
A = acos(clamp(cos A, −1, 1))
if sin H > 0 then A = 360 − A        (object is west of the meridian)
```

A is the azimuth measured from **north, clockwise** (N=0, E=90, S=180, W=270). Convert A to a 16-point compass label (N, NNE, NE, ENE, E…).

Optional: add atmospheric refraction for alt > −1°: `R = 1.02 / tan((alt + 10.3/(alt + 5.11)) rad)` arc-minutes, `alt += R/60`.

### 6.6 Rise, transit, set

```
h0 = −0.5667°   (stars/galaxies, includes refraction)   ·   −0.833° for the Sun
cos H0 = (sin h0 − sin φ · sin δ) / (cos φ · cos δ)
if cos H0 < −1 → circumpolar (never sets)
if cos H0 >  1 → never rises at this latitude
H0 = acos(cos H0)
```

Transit happens when the hour angle is 0, so solve for the next time with LST = α. Then rise = transit − H0 and set = transit + H0. Sidereal hours convert to clock hours via `÷ 1.0027379`. Transit altitude = `90 − |φ − δ|`. Transit azimuth is 180 (S) if δ < φ, else 0 (N).

Compute each time from the transit, not from "now", and handle day wrap: rise may be yesterday and set tomorrow.

### 6.7 Sun and darkness window

Use the low-precision solar position (Astronomical Almanac), with n = D:

```
L = 280.460 + 0.9856474·n          (mean longitude)
g = 357.528 + 0.9856003·n          (mean anomaly)
λsun = L + 1.915·sin g + 0.020·sin 2g
ε = 23.439 − 0.0000004·n
α = atan2(cos ε · sin λsun, cos λsun)
δ = asin(sin ε · sin λsun)
```

Sunset uses h0 = −0.833°. Astronomical darkness uses h0 = −18°. The **best viewing window** is when the Sun is below −18° **and** the object's altitude is above 20°. Show the peak time inside that window if there is one.

### 6.8 Test vector — tests MUST pass

Location Islamabad φ = 33.6844° N, λ = 73.0479° E. Time 2026‑10‑28 15:00 UTC (20:00 PKT). Object M31: α = 10.6847° (00h42m44s), δ = +41.2692°.

| Quantity | Expected | Tolerance |
|---|---|---|
| JD | 2461342.125 | ±0.0001 |
| D | 9797.125 | ±0.0001 |
| GMST | 261.971° | ±0.01° |
| LST | 335.019° | ±0.01° |
| H | −35.666° | ±0.01° |
| Altitude (no refraction) | 60.92° | ±0.05° |
| Azimuth | 64.38° (ENE) | ±0.1° |
| H0 (h0 = 0) | 125.80° | ±0.05° |
| Transit | ≈ 22:22 PKT | ±2 min |
| Rise / Set (h0 = 0) | ≈ 14:00 / 06:44 PKT | ±3 min |
| Transit altitude | 82.4° | ±0.05° |

More cross-checks for the same time and place: Vega (α 279.23°, δ 38.78°) → alt ≈ 45.4°, az ≈ 293°. Pleiades (α 56.75°, δ 24.12°) → alt ≈ 19.6°, az ≈ 73.5°.

Write `test/astro_test.dart` with these cases **before** building the UI that depends on them.

### 6.9 Precession (optional, nice for marks)

Catalog coordinates are J2000. In 2026 the drift is about 0.36° in RA for many objects. Implement the simple precession formulas (Meeus ch. 21) in `precession.dart` behind a setting. Leave it off for the test vector above.

### 6.10 Planets (Phase 6)

Planets move, so they can't be stored with a fixed RA/Dec. Implement Paul Schlyter's "How to compute planetary positions" simplified orbital elements to get geocentric RA/Dec for Mercury–Saturn, the Moon and the Sun. Accuracy of about 1–2 arc-minutes is fine.

---

## 7. Catalog data (`assets/data/catalog.json`)

Ship around 120 objects: the 110 Messier objects plus the brightest named stars (Sirius, Canopus, Arcturus, Vega, Capella, Rigel, Procyon, Betelgeuse, Altair, Aldebaran, Antares, Spica, Pollux, Fomalhaut, Deneb, Regulus, Polaris…). Get J2000 RA/Dec and magnitude from a public catalog: SIMBAD, or the public-domain Messier and Yale Bright Star tables. Keep the values honest — do not invent coordinates.

```json
{
  "id": "m31",
  "name": "Andromeda Galaxy",
  "catalog": "M31",
  "type": "galaxy",
  "raDeg": 10.6847,
  "decDeg": 41.2692,
  "mag": 3.4,
  "distance": "2.5 million ly",
  "image": "assets/backgrounds/bg-detail.jpg",
  "summary": "Nearest large spiral galaxy, visible to the naked eye from dark sites."
}
```

`type` is one of `star | planet | galaxy | nebula | cluster`.

---

## 8. Location and sensors

- **geolocator.** Request permission on the Permission screen, then use `getCurrentPosition(desiredAccuracy: high)` and `getPositionStream(distanceFilter: 100)`. Also store the altitude in metres (needed for N2YO). Cache the last fix in `shared_preferences` and allow a manual location override.
- **Reverse geocoding** for the "Islamabad" chip is optional (`geocoding` package). Fall back to showing coordinates.
- **Heading.** Read the true heading from `flutter_compass`. Smooth it with a low-pass filter (α = 0.15) and handle the 359°→0° wrap.
- **Pitch** comes from `sensors_plus` accelerometer: `pitch = atan2(−ax, sqrt(ay² + az²))` with the phone held upright, camera facing the sky. Calibrate the sign on a real device and smooth it.
- **Pointer math.** `deltaAz = normalise180(targetAz − heading)` drives "Turn right" if positive and "Turn left" if negative. `deltaAlt = targetAlt − pitch` drives "Tilt up/down".
- **Permissions.** Android needs `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS` and `INTERNET`. iOS needs `NSLocationWhenInUseUsageDescription` and `NSMotionUsageDescription`.

---

## 9. Satellites API

### N2YO (positions and visible passes)

Free API key from n2yo.com. Store it in `.env` as `N2YO_API_KEY`. Base URL: `https://api.n2yo.com/rest/v1/satellite/`

| Call | Endpoint |
|---|---|
| Current position | `positions/{noradId}/{lat}/{lng}/{altMeters}/1/&apiKey=KEY` |
| Visible passes | `visualpasses/{noradId}/{lat}/{lng}/{altMeters}/{days}/{minVisibilitySeconds}/&apiKey=KEY` |
| TLE | `tle/{noradId}&apiKey=KEY` |
| Above me | `above/{lat}/{lng}/{alt}/{radiusDeg}/{categoryId}/&apiKey=KEY` |

N2YO has hourly request limits per endpoint, so check the current numbers on their API page. Cache responses:
- Positions: 10 s.
- Passes: 1 h.
- Never poll faster than every 10 s.

For smooth movement between polls, interpolate between the last two positions.

### CelesTrak (orbit elements, no key)

`https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=json` returns the GP/TLE data for one satellite. Use it to show orbit info such as inclination and period, and as a fallback source.

Default satellites:
- ISS: 25544
- Tiangong / CSS: 48274
- Hubble: 20580

### Pass card text

Build it from the `visualpasses` fields `startAzCompass`, `maxEl`, `endAzCompass`, `startUTC` and `duration`. For example: "Appears WSW, climbs to 52°, gone NE after 4 min".

---

## 10. Nearby dark-sky spots

Phase 1 uses a small local JSON list of public places with `name`, `lat`, `lng`, `note` and `skyQuality` (`fair | good | best`). Compute the distance from the user with the haversine formula and sort by distance.

Islamabad seed list: Shakarparian Park, Daman-e-Koh, Pir Sohawa. Look up and enter their real coordinates rather than guessing.

Stretch goal: query the OpenStreetMap Overpass API for parks and viewpoints within 30 km.

Map tiles come from a dark OSM-based style. CARTO dark_all is one option; check its usage terms and add the attribution widget.

---

## 11. Notifications (Tonight's plan)

Use `flutter_local_notifications` with zoned schedules. Supported events:
- Object peak
- Darkness start
- Satellite pass, 10 minutes before

Each event's reminder switch persists its state. Re-schedule all reminders whenever the location changes by more than 50 km or the date changes.

---

## 12. Build phases (do them in order)

Each phase ends with its **acceptance check**. Commit after each phase.

1. **Setup and design system.** Create the project, add packages, fonts, colors, theme, GlassCard, GradientButton, LightBeams, HeroBackground, SkyNavBar and the go_router skeleton with all 11 routes as placeholders.
   *Check:* the app runs, all routes open, and the beams animate.
2. **Astro core and tests.** Implement `lib/astro/*` and `test/astro_test.dart`.
   *Check:* `flutter test` passes every value in 6.8.
3. **Location flow.** Build Onboarding, Permission and the location service with the manual override.
   *Check:* a real device shows correct coordinates on Home, and denying permission shows the fallback state.
4. **Home, Explore and Object detail.** Load the catalog, show live alt/az, the altitude chart, rise/peak/set times and the dark window.
   *Check:* M31 on Home matches the test vector when the clock is mocked to the test time.
5. **Pointer and Math.** Add the compass and tilt UI, haptics, and the live math steps.
   *Check:* on a phone, pointing at the Moon or a bright star lines up within about 5°.
6. **Satellites.** Add the N2YO and CelesTrak clients, caching, the ISS card, the pass list and the alert.
   *Check:* the ISS position updates and the next pass matches n2yo.com for the same location.
7. **Map, Tonight and Profile.** Add flutter_map spots, the timeline with reminders, and settings.
   *Check:* a scheduled reminder fires on device.
8. **Planets and polish.** Add planet positions, Cosmo poses, loading, empty and error states, reduce-motion support, and accessibility labels.
   *Check:* no overflow warnings at 360 px width, and TalkBack/VoiceOver reads every control.
9. **Lab deliverables.** Write a README with screenshots, an architecture diagram, an explanation of the formulas, and an APK build (`flutter build apk --release`).

---

## 13. Code rules for Claude Code

- Keep the math in `lib/astro`, with a doc comment on every formula and its source (Meeus, *Astronomical Algorithms*; Astronomical Almanac).
- Use UTC everywhere internally.
- Never hard-code the API key; read it from `.env`. Add `.env` to `.gitignore` and commit a `.env.example`.
- Widgets stay small and composable. Screens hold layout only; controllers and providers hold logic.
- Do not invent data. Coordinates come from catalogs, passes come from the API, and distances are computed. Show a placeholder when a value is unknown.
- Respect reduced motion. All text must meet 4.5:1 contrast. Every icon-only button needs a semantic label.
- When unsure about a package API, check its pub.dev page instead of guessing.
- Run `flutter analyze` and `flutter test` before saying a phase is done.

---

## 14. Done means

- All 11 screens are built and match the design.
- `flutter test` passes and `flutter analyze` is clean.
- On a real phone in Islamabad (or anywhere), picking an object shows the correct live position, rise/peak/set times and a working pointer.
- The live ISS position and next pass load from N2YO.
- A release APK builds.
