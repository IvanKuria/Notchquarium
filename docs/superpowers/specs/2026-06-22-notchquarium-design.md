# Notchquarium — Design Spec

**Date:** 2026-06-22
**Status:** Approved (design), pending implementation plan
**Project location:** `~/Documents/Notchquarium`

## One-liner

A living Frutiger Aero reef that hangs from the macOS notch and visualizes your
Mac's vitals as an aquarium ecosystem: battery = water level, CPU = bubbles,
RAM = water clarity, and your busiest apps swim around as fish.

## Why

Frutiger Aero (the glossy, water-droplet, tropical-fish, aqua-gel aesthetic of
2004–2013) is having a strong nostalgia resurgence. macOS itself was born in
that era (Aqua), so a notch aquarium returns the Mac to its own visual genetic
memory. The aesthetic is the marketing: the app wins on screenshots and short
video, which suits "this Mac app solves…" / "why you need this Mac app" content.

The hook that makes it more than a toy: the aquarium is a **real system
monitor**. "The fish told me Chrome was eating my CPU before Activity Monitor
did."

## Aesthetic direction (Frutiger Aero)

- Glossy aqua → sky-blue gradients, specular highlights, rounded glass tank
- Water droplets, rising bubbles, volumetric light rays, occasional lens flare
- Skeuomorphic gel/jelly controls and stat readouts
- Tropical reef furniture: gravel, coral, plants, shells
- Humanist sans for labels (system font is fine; Frutiger/Myriad feel)

## Interaction model (three notch states)

The whole app is one transparent, borderless, floating panel anchored to the
notch. It hangs **down** from the notch; the notch's black void reads as the
water surface — fish dip up into it, bubbles rise into it and pop.

1. **Ambient (default, ~95% of the time)**
   - Sits at the notch. A fish silhouette occasionally glides across and dips in.
   - Tiny bubbles drift up into the notch.
   - Two micro-stat "wings" flank the notch: battery as a draining water droplet,
     CPU as bubble density.

2. **Hover peek**
   - A shallow glass tank slides down (~80px) showing 2–3 fish and the water level.

3. **Expanded (click)**
   - Full glossy tank panel with the complete ecosystem and a gel stat bar.
   - Auto-collapses on mouse-out after a short delay.

## System-monitor mapping

| Visual | Data | Source API |
|---|---|---|
| Water **level** | battery % | IOKit / `IOPSCopyPowerSourcesInfo` |
| Bubble **density / speed** | total CPU % | `host_processor_info` |
| Water **clarity** (clear → murky green) | memory pressure | `host_statistics64` (`vm_statistics64`) |
| **Fish** (count, size, speed, color) | top processes by CPU | `libproc` / sampling |
| Fish **tooltip** | app name + its CPU % | per-process sample |
| Fish **darts up into notch** | new notification (stretch) | notification observation |
| Surface **shimmer** tint | time of day | clock |

A fish carries its app; hovering it shows a glossy tooltip like
"Google Chrome — 41% CPU". Bigger/faster fish = heavier CPU.

## Architecture

Three composited layers inside one window:

1. **Water layer** — SwiftUI gradient + glass chrome (stat bar, highlights, frame).
2. **Particle layer** — SpriteKit emitters for bubbles and light rays.
3. **Sprite layer** — SpriteKit fish driven by a small steering/physics sim.

Components (each independently understandable and testable):

- **`NotchWindow` / panel** — borderless `NSPanel`, `.nonactivating`, floating,
  transparent; anchored to the notch. Reuses the geometry approach proven in the
  Blip project (notch frame math, expand-down animation, mouse-tracking).
- **`NotchGeometry`** — computes notch rect + the tank frame for each state.
- **`SystemVitals` (actor)** — polls every ~2s, publishes an immutable
  `VitalsSnapshot { batteryPercent, cpuTotal, memoryPressure, topProcesses[] }`.
- **`AquariumScene` (SpriteKit `SKScene`)** — owns fish, bubble emitter, light
  rays, water tint; binds to `VitalsSnapshot` and animates properties toward new
  values.
- **`Fish`** — a sprite + steering behavior; exposes `bind(process:)` mapping
  CPU% → size/speed/color and stores the app identity for tooltips.
- **`StatBar` (SwiftUI)** — gel readout of battery / CPU / RAM, drawn over the
  scene in the expanded state.
- **Menu-bar item + Settings** — poll rate, which stats are shown, fish theme.

### Data flow

`SystemVitals` (timer) → publishes `VitalsSnapshot` → `AquariumScene` observes →
diffs against current fish set (add/remove/retune fish), updates water level,
bubble rate, and clarity. SwiftUI chrome observes the same snapshot for the
stat bar. The aquarium is purely a *view* of the latest snapshot.

### Boundaries

- `SystemVitals` knows nothing about rendering; it only produces snapshots.
- `AquariumScene` knows nothing about how vitals are gathered; it consumes a
  snapshot struct. Either side can be tested with a fake on the other.

## Error handling

- Battery API unavailable (desktop Mac, no battery) → water level defaults to
  full; battery wing hidden.
- Process sampling fails or returns empty → keep last good fish set; don't crash
  or empty the tank.
- No notch (non-notch display / external monitor) → fall back to a top-center
  floating tank using the same scene (placement abstraction already needed for
  the geometry layer).

## Testing

- `SystemVitals` mapping: feed known IOKit/host values → assert snapshot fields.
- Snapshot → scene diff: given two snapshots, assert correct fish added/removed
  and water level/clarity targets (test the diff logic without rendering).
- Geometry: notch rect + tank frame per state are computed correctly for sample
  screen configs (with-notch and without-notch).

## MVP scope (v1 — the first video)

1. Notch panel with the three states (ambient / hover / expanded).
2. Water level = battery, bubbles = CPU, clarity = RAM.
3. Fish = top 5 CPU processes, with size/speed/color mapping + hover tooltip.
4. Frutiger Aero art pass: gradient, specular highlight, gravel + plant, light
   rays, lens flare, gel stat bar.
5. Menu-bar item with minimal settings (poll rate, theme on/off).

## Out of scope (v2+)

- Notifications-as-fish darting into the notch.
- Themes (koi pond, tropical reef, deep abyss).
- Feeding / petting interactions.
- Screensaver mode.
- Disk / network / temperature mappings.

## Tech stack

- Swift, SwiftUI for chrome, **SpriteKit** for fish/bubbles/particles.
- AppKit `NSPanel` for the notch window.
- IOKit + Mach host APIs for vitals; `libproc` for per-process CPU.
- macOS 14+ target (notch hardware era).
