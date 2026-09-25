# Guardify — Color System Design

Status: DRAFT (initial inventory + proposed palette architecture)
Scope: All screens across all 19 features. This document is the single source of
truth for guardify color usage and the roadmap to palette-based theming.

---

## 1. Current state (AS-IS inventory)

### 1.1 Color definition file
`lib/core/design/colors.dart` — top-level consts (39 named values) + `Gradients`.
Identity: **red/crimson** family, seed `#E74C3C`, deep red primary `#8B0000`.

| Group | Consts | Role |
|---|---|---|
| Primary ramp | `primaryColor #8B0000`, `primaryDark #5D0000`, `primaryAccent #BB0000` | brand primary |
| Primary tonal | `primary10..90` | tint/shade ramp (#FDEDEA → #E74C3C → #922B21) |
| Secondary tonal | `secondary10..90` (mirror of primary) | secondary accents |
| Neutral ramp | `neutral5..90` | greys + surfaces (#FFF → #101820) |
| Semantic | `errorColor #E74C3C`, `successColor`, `normalColor`, `disabledColor`, `focusColor` | stateful feedback |
| Text | `appTextColor`, `appHintColor` | text roles |
| Surfaces | `bgColor`, `bgColorDark`, `cardColor`, `tabbarColor`, `inputColor`, `babyBlueColor` | containers |
| Misc | `white`, `grey`, `greySecond`, `darkGrey`, `favoriteColor` | ad-hoc |
| Gradients | `Gradients.primary()`, `.primaryAccent()`, `.neutral()`, `.cardGradient()` | gradient fills |

### 1.2 Theme wiring
`lib/main.dart` (~352): inline `ThemeData(useMaterial3: true, colorScheme:
ColorScheme.fromSeed(seedColor: Color(0xFFE74C3C), brightness: light),
appBarTheme: ...)`. `MaterialApp` accepts `theme`/`darkTheme`/`themeMode`.

### 1.3 Usage magnitude (verified by scan)
- 601 Dart files; 90 import `core/design/colors.dart`.
- 66 screen/page/view files across 19 features (largest: attendance 57,
  panic_button 53, cuti 46, patrol 45, schedule 40, laporan_kejadian 38).
- Semantic-const usage (excluding `Colors.*` collisions): `primaryColor` **474**,
  `neutral90` 138, `neutral50` 117, `neutral70` 83, `errorColor` 43,
  `successColor` 26, plus ~30 other roles.
- Hardcoded/`Colors.*` outside the design file: **83 distinct raw expressions,
  ~2704 uses** — dominated by `Colors.white` 682, `Colors.grey` 657,
  `Colors.red` 282, `Colors.black87` 227, `Colors.black` 147, `Colors.green` 125,
  and raw hex `Color(0xFF...)` (e.g. `#E74C3C` x73, `#B71C1C` x80, `#8B1538` x23,
  `#2C5F7C` x16).

### 1.4 Problems found
1. **No single palette object.** Everything is top-level consts — you cannot
   switch the brand hue without editing the file and recompiling.
2. **Heavy hardcoding.** ~2704 raw `Colors.*`/hex usages bypass the design file;
   a palette change won't reach them unless they are migrated to roles.
3. **Dart const constraint.** `const SomeWidget(color: <const>)` (38 named-color
   importers use const contexts) can't read a runtime getter — needs `const`
   stripped at those call sites for live re-skin (see §5).
4. **Semantic overlap.** `grey`/`neutral*`/`darkGrey`/`Colors.grey` all overlap;
   `Colors.red` vs `primaryColor` vs `errorColor` are ambiguous.

---

## 2. Proposed architecture (TO-BE)

### 2.1 Token model
Introduce a `Palette` object holding every **semantic role** for one accent,
with both light and dark variants. Roles are stable; only values change per
palette/brightness.

Grouped roles:
- **brand**: primary, primaryDark, primaryAccent, onPrimary
- **tonal**: primary10/30/50/70/90 (secondary derived by mirror)
- **neutral**: neutral5/10/20/30/50/70/90
- **semantic**: error, success, warning, info, focus, disabled
- **text**: textPrimary, textSecondary/textHint, onColor
- **surface**: background, surface, card, tabbar, input, babyBlue
- **state**: (derived) selected, unselected, overlay
- **gradient**: primaryGradient, primaryAccentGradient, neutralGradient, cardGradient

### 2.2 Palettes (v1 — 4 accents) with brightness
Each row = `seed` (drives Material `ColorScheme.fromSeed`) + deep/bright accents.

| Palette | seed | primary (base) | primaryDark | primaryAccent |
|---|---|---|---|---|
| `Palettes.guardify` (default, current) | `#E74C3C` | `#8B0000` | `#5D0000` | `#BB0000` |
| `Palettes.ocean` | `#1E88E5` | `#0B3D91` | `#072A63` | `#2F9BFF` |
| `Palettes.forest` | `#2E7D32` | `#1B5E20` | `#123F16` | `#43A047` |
| `Palettes.amber` | `#FFB300` | `#B26500` | `#7A4300` | `#FFB300` |

Each palette ships a **light** and **dark** resolution (background/surface/text
invert; accent ramp stays). This mirrors the existing neutral5..90 + bgColor/+
bgColorDark split.

### 2.3 Brightness mode
`themeMode`: `system | light | dark` (Material `ThemeMode`, already in the SDK
framework). Persisted with the chosen palette.

---

## 3. Per-feature usage map (which colors each feature leans on)

| Feature | dart files | dominant roles |
|---|---|---|
| attendance | 57 | primaryColor, neutral50/90, Colors.grey, successColor |
| panic_button | 53 | Colors.red, errorColor, neutral90/70, primaryColor |
| cuti | 46 | primaryColor, neutral50, Colors.grey/black87 |
| patrol | 45 | neutral50/90, primaryColor, Colors.grey |
| schedule | 40 | primaryColor, neutral70/50, Colors.grey |
| laporan_kejadian | 38 | primaryColor, errorColor(Colors.red), neutral50 |
| test_result | 31 | successColor(Colors.green), primaryColor, neutral |
| company_regulations | 30 | neutral50, primaryColor, grey |
| auth | 30 | primaryColor, Colors.red (error), neutral |
| bmi | 29 | primaryColor, neutral50, status colors |
| profile | 27 | primaryColor, neutral, babyBlueColor |
| home | 25 | primaryColor, neutral, tabbarColor |
| report* (laporan_kegiatan) | 21 | primaryColor, Colors.red/green status |
| personnel | 20 | neutral, primaryColor |
| tugas_lanjutan | 20 | primaryColor, neutral |
| news / chat / notification / shift | 15/15/2/3 | primary, neutral, semantic |

Bottom line: **`primaryColor` (474) + neutral ramp (335+) + error/success** are
the load-bearing roles for live palette switching; the 2367 `Colors.*` uses are
the migration target.

---

## 4. Migration plan (keep-96%-of-files-working trick)

Backward-compatible path so 90 importers keep compiling:

1. **Introduce** `Palettes` enum + `ColorPalette` class (roles) + `ThemeController`
   (ChangeNotifier holding current palette + brightness, persisted to
   `shared_preferences`).
2. **Repoint** `colors.dart` consts to read from the active palette via getters
   (keep the same names) — EXCEPT the Dart `const`-arg call sites (§5).
3. **Build ThemeData** from selected palette: light + dark, fed to `MaterialApp`
   (`theme:`, `darkTheme:`, `themeMode:`). Runtime change = rebuild
   `_GuardifyAppState` with new ThemeData.
4. **Add `/settings`** screen: palette swatch grid (4 palettes x light/dark
   preview) + brightness toggle. Saves to prefs, notifies controller, rebuilds.
5. **Migrate** the ~2704 hardcoded `Colors.*`/hex over subsequent PRs, feature by
   feature, replacing with semantic roles so every palette works everywhere.

**Phase split (recommended):**
- Phase 1 (this build): palette engine + controller + `/settings` + ThemeData
  wiring + doc. Palette switch reaches framework chrome + every `colors.dart`
  role that is NOT inside a raw-`const` widget arg.
- Phase 2 (follow-up): strip `const` at the ~const-arg call sites so NAMED roles
  re-skin live (same trick documented for the sibling app).
- Phase 3: migrate hardcoded `Colors.*`/hex → roles feature by feature.

---

## 5. Known limitation — Dart `const` context

`const BorderSide(color: <named>)`, `const Icon(Icons.x, color: <named>)`, etc.
require a compile-time constant. A palette *getter* is not constant. Therefore
in Phase 1 these specific call sites cannot read the live palette; the underlying
Material/Framework chrome still re-skins via ThemeData. Phase 2 removes the
`const` keyword at those sites to unlock full live re-skin. This is a mechanical
edit, tracked per file, no logic change.

---

## 6. Accessibility notes (v2 target)
- Ensure onPrimary contrast ≥ 4.5:1 on accent-900 surfaces (verify `forest`
  amber-on-dark).
- status colors: error/success must stay distinguishable under `Colors.orange`,
  `Colors.amber` palette swaps.
- Neutral ramps must keep ≥ 3:1 for borders/dividers, ≥ 4.5:1 for body text.

---

## 7. Open questions for design sign-off
1. Confirm `Palettes.ocean/forest/amber` hues (or replace with client brand).
2. Light/dark handling per palette: derived via M3 `ColorScheme.fromSeed(brightness)`.
3. ~~Should the picker be under /profile or a new /settings route?~~ → **Resolved:**
   a "Tema" menu entry added in the existing Profile screen
   (`lib/features/profile/presentation/pages/profile_screen.dart`), pushing
   `ThemePickerScreen`. Theme settings live in-feature; no new route needed.