# Notchquarium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Frutiger Aero aquarium that hangs from the macOS notch and visualizes the Mac's vitals (battery, CPU, RAM, top processes) as a living SpriteKit ecosystem.

**Architecture:** One transparent borderless `NSPanel` anchored to the notch hosts a SpriteKit `AquariumScene` plus SwiftUI glass chrome. A `SystemVitals` actor polls the OS every ~2s and publishes an immutable `VitalsSnapshot`; the scene is a pure view of that snapshot. Pure-logic units (vitals mapping, snapshot→fish diff, notch geometry) are TDD'd; rendering is layered on top.

**Tech Stack:** Swift 5.9+, Swift Package Manager (executable target), AppKit (`NSPanel`), SwiftUI (chrome), SpriteKit (fish/particles), IOKit + Mach host APIs (vitals), `libproc` (per-process CPU). macOS 14+.

## Global Constraints

- macOS deployment target: **14.0** (notch hardware era).
- Swift tools version: **5.9**.
- App runs as a menu-bar/agent app: `NSApp.setActivationPolicy(.accessory)` — no Dock icon.
- No third-party dependencies. System frameworks only.
- The aquarium is a *view* of the latest `VitalsSnapshot`; rendering code never reads the OS directly.
- Build/test from CLI: `swift build`, `swift test`, `swift run Notchquarium`.
- All commits end with the Co-Authored-By trailer used in the repo.

---

## File Structure

```
Notchquarium/
├── Package.swift
├── README.md
├── LICENSE
├── .gitignore
├── .github/workflows/ci.yml
├── docs/superpowers/{specs,plans}/...
├── Sources/Notchquarium/
│   ├── main.swift                  # entry: app delegate, activation policy
│   ├── App/
│   │   ├── AppDelegate.swift       # wires window + menu bar + vitals timer
│   │   └── MenuBarController.swift # status item + settings menu
│   ├── Window/
│   │   ├── NotchGeometry.swift     # pure: notch rect + tank frame per state  (TDD)
│   │   └── NotchPanel.swift        # NSPanel subclass, state animation
│   ├── Vitals/
│   │   ├── VitalsSnapshot.swift    # immutable model + ProcessSample          (TDD model)
│   │   ├── SystemVitals.swift      # actor: timer + publish
│   │   ├── BatteryReader.swift     # IOKit battery %                          (TDD mapping)
│   │   ├── CPUReader.swift         # host_processor_info total CPU            (TDD mapping)
│   │   ├── MemoryReader.swift      # host_statistics64 memory pressure        (TDD mapping)
│   │   └── ProcessReader.swift     # libproc top-N by CPU
│   └── Aquarium/
│       ├── AquariumScene.swift     # SKScene: water, emitters, applies snapshot
│       ├── FishNode.swift          # SKNode fish + steering + app identity
│       ├── FishDiff.swift          # pure: snapshot.topProcesses → fish ops   (TDD)
│       ├── BubbleEmitter.swift     # SKEmitterNode factory (bubbles)
│       └── StatBar.swift           # SwiftUI gel readout overlay
└── Tests/NotchquariumTests/
    ├── NotchGeometryTests.swift
    ├── VitalsMappingTests.swift
    └── FishDiffTests.swift
```

---

### Task 1: Project scaffold + professional repo furniture

**Files:**
- Create: `Package.swift`, `.gitignore`, `README.md`, `LICENSE`, `.github/workflows/ci.yml`
- Create: `Sources/Notchquarium/main.swift`, `Sources/Notchquarium/App/AppDelegate.swift`

**Interfaces:**
- Produces: a buildable, runnable agent app that opens an empty borderless panel near the notch. `AppDelegate` is the `NSApplicationDelegate`.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchquarium",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Notchquarium", path: "Sources/Notchquarium"),
        .testTarget(name: "NotchquariumTests", dependencies: ["Notchquarium"], path: "Tests/NotchquariumTests"),
    ]
)
```

- [ ] **Step 2: Write `.gitignore`**

```
.DS_Store
.build/
*.xcodeproj
.swiftpm/
DerivedData/
```

- [ ] **Step 3: Write `Sources/Notchquarium/main.swift`**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar/agent app, no Dock icon
app.run()
```

- [ ] **Step 4: Write a minimal `AppDelegate.swift`** that, on launch, creates a borderless transparent `NSPanel` (300x180) centered under the top of the main screen and shows it. (Replaced in later tasks.)

- [ ] **Step 5: Write `README.md`, `LICENSE` (MIT), and `.github/workflows/ci.yml`** (macOS runner: `swift build` + `swift test`). See Task 10 for the full README; a stub title + one-line description is fine here.

- [ ] **Step 6: Build & run**

Run: `swift build` → Expected: Compiling, `Build complete!`
Run: `swift run Notchquarium` (manual visual check: an empty panel appears at top center) then quit.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: project scaffold + repo furniture"
```

---

### Task 2: `VitalsSnapshot` model

**Files:**
- Create: `Sources/Notchquarium/Vitals/VitalsSnapshot.swift`
- Test: `Tests/NotchquariumTests/VitalsMappingTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct ProcessSample: Equatable { let pid: Int32; let name: String; let cpuPercent: Double }
  struct VitalsSnapshot: Equatable {
      let batteryFraction: Double?   // 0...1, nil if no battery
      let cpuFraction: Double        // 0...1 total
      let memoryUsedFraction: Double // 0...1
      let topProcesses: [ProcessSample] // sorted desc by cpuPercent
  }
  ```

- [ ] **Step 1: Write failing test** asserting a `VitalsSnapshot` keeps `topProcesses` order and is `Equatable`.

```swift
import XCTest
@testable import Notchquarium

final class VitalsMappingTests: XCTestCase {
    func testSnapshotStoresFields() {
        let p = ProcessSample(pid: 1, name: "Chrome", cpuPercent: 41)
        let s = VitalsSnapshot(batteryFraction: 0.8, cpuFraction: 0.23, memoryUsedFraction: 0.5, topProcesses: [p])
        XCTAssertEqual(s.topProcesses.first?.name, "Chrome")
        XCTAssertEqual(s, s)
    }
}
```

- [ ] **Step 2: Run** `swift test --filter VitalsMappingTests` → Expected: FAIL (types undefined).
- [ ] **Step 3: Implement** the two structs in `VitalsSnapshot.swift`.
- [ ] **Step 4: Run** `swift test --filter VitalsMappingTests` → Expected: PASS.
- [ ] **Step 5: Commit** `feat(vitals): VitalsSnapshot + ProcessSample model`.

---

### Task 3: Vitals readers (battery / CPU / memory) with TDD'd mapping

**Files:**
- Create: `Sources/Notchquarium/Vitals/{BatteryReader,CPUReader,MemoryReader}.swift`
- Test: `Tests/NotchquariumTests/VitalsMappingTests.swift` (extend)

**Interfaces:**
- Produces:
  - `CPUReader.fraction(prev:, cur:) -> Double` — pure function mapping two `host_cpu_load_info`-style tick tuples `(user,system,idle,nice)` to a 0...1 busy fraction. (The live tick reading wraps this.)
  - `MemoryReader.usedFraction(active:wired:compressed:total:) -> Double` — pure.
  - `BatteryReader.fraction() -> Double?` — live IOKit (not unit tested; isolated).

- [ ] **Step 1: Write failing tests** for the pure mappers:

```swift
func testCPUFractionFromDeltas() {
    // busy 30 ticks, idle 70 ticks -> 0.3
    let f = CPUReader.fraction(prevBusy: 0, prevIdle: 0, curBusy: 30, curIdle: 70)
    XCTAssertEqual(f, 0.3, accuracy: 0.001)
}
func testMemoryUsedFraction() {
    let f = MemoryReader.usedFraction(usedBytes: 8_000_000_000, totalBytes: 16_000_000_000)
    XCTAssertEqual(f, 0.5, accuracy: 0.001)
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `CPUReader.fraction(prevBusy:prevIdle:curBusy:curIdle:)` = `Δbusy / (Δbusy+Δidle)` clamped 0...1; `MemoryReader.usedFraction(usedBytes:totalBytes:)` = `used/total` clamped. Add the live readers (`liveSample()` reading `host_statistics`/`host_processor_info`, `BatteryReader.fraction()` via `IOPSCopyPowerSourcesInfo`) below the pure funcs.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(vitals): battery/cpu/memory readers with tested mapping`.

---

### Task 4: Process reader (top-N by CPU)

**Files:**
- Create: `Sources/Notchquarium/Vitals/ProcessReader.swift`

**Interfaces:**
- Produces: `ProcessReader.topProcesses(limit: Int) -> [ProcessSample]` using `proc_listpids` + `proc_pid_rusage`/`proc_name`, sampling CPU between calls (keeps a prev-tick cache internally).

- [ ] **Step 1: Implement** `ProcessReader` (a class holding previous per-pid CPU times; computes delta CPU% per pid, returns top `limit` sorted desc). No unit test (depends on live OS); covered by the diff test in Task 7 via injected samples.
- [ ] **Step 2: Smoke test** — add a temporary `print(ProcessReader().topProcesses(limit: 5))` path behind a debug flag, run `swift run`, confirm real process names print, then remove the print.
- [ ] **Step 3: Commit** `feat(vitals): top-process CPU sampler`.

---

### Task 5: `SystemVitals` actor (polling + publishing)

**Files:**
- Create: `Sources/Notchquarium/Vitals/SystemVitals.swift`

**Interfaces:**
- Consumes: readers from Tasks 3–4.
- Produces:
  ```swift
  @MainActor final class SystemVitals: ObservableObject {
      @Published private(set) var snapshot: VitalsSnapshot
      func start(interval: TimeInterval = 2.0)
      func stop()
  }
  ```

- [ ] **Step 1: Implement** `SystemVitals` driving a `Timer` that assembles a `VitalsSnapshot` from the readers and publishes it on `@Published snapshot`.
- [ ] **Step 2: Wire** `AppDelegate` to create a `SystemVitals`, call `start()`, and log snapshots temporarily.
- [ ] **Step 3: Run** `swift run`, confirm snapshots update ~every 2s, remove the log.
- [ ] **Step 4: Commit** `feat(vitals): SystemVitals polling actor`.

---

### Task 6: `NotchGeometry` (pure, TDD)

**Files:**
- Create: `Sources/Notchquarium/Window/NotchGeometry.swift`
- Test: `Tests/NotchquariumTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum NotchState { case ambient, peek, expanded }
  enum NotchGeometry {
      static func notchRect(screenFrame: CGRect, notchSize: CGSize) -> CGRect
      static func tankFrame(screenFrame: CGRect, notchSize: CGSize, state: NotchState) -> CGRect
  }
  ```

- [ ] **Step 1: Write failing tests**: notch is centered at top of screen; tank is centered under the notch; expanded height > peek height > ambient height; tank width ≥ notch width.

```swift
func testNotchCenteredAtTop() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let r = NotchGeometry.notchRect(screenFrame: screen, notchSize: CGSize(width: 200, height: 32))
    XCTAssertEqual(r.midX, screen.midX, accuracy: 0.5)
    XCTAssertEqual(r.maxY, screen.maxY, accuracy: 0.5)
}
func testExpandedTallerThanPeek() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982); let n = CGSize(width: 200, height: 32)
    XCTAssertGreaterThan(NotchGeometry.tankFrame(screenFrame: screen, notchSize: n, state: .expanded).height,
                         NotchGeometry.tankFrame(screenFrame: screen, notchSize: n, state: .peek).height)
}
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** geometry (heights: ambient = notch height, peek = 90, expanded = 240; widths: peek = notch+40, expanded = 460; centered on `screenFrame.midX`, top-aligned to `maxY`). **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(window): notch + tank geometry (tested)`.

---

### Task 7: `FishDiff` (pure, TDD) — snapshot → fish operations

**Files:**
- Create: `Sources/Notchquarium/Aquarium/FishDiff.swift`
- Test: `Tests/NotchquariumTests/FishDiffTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum FishOp: Equatable { case add(ProcessSample); case remove(pid: Int32); case update(ProcessSample) }
  enum FishDiff { static func ops(current: [ProcessSample], next: [ProcessSample]) -> [FishOp] }
  ```

- [ ] **Step 1: Write failing tests**: new pid → `.add`; gone pid → `.remove`; same pid different cpu → `.update`; stable identical → `[]`.

```swift
func testAddRemoveUpdate() {
    let a = ProcessSample(pid: 1, name: "A", cpuPercent: 10)
    let b = ProcessSample(pid: 2, name: "B", cpuPercent: 20)
    let aHot = ProcessSample(pid: 1, name: "A", cpuPercent: 55)
    XCTAssertEqual(FishDiff.ops(current: [a], next: [a, b]), [.add(b)])
    XCTAssertEqual(FishDiff.ops(current: [a, b], next: [a]), [.remove(pid: 2)])
    XCTAssertEqual(FishDiff.ops(current: [a], next: [aHot]), [.update(aHot)])
    XCTAssertEqual(FishDiff.ops(current: [a], next: [a]), [])
}
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** keyed by `pid`. **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(aquarium): fish diff engine (tested)`.

---

### Task 8: `AquariumScene` + bubbles + water (SpriteKit)

**Files:**
- Create: `Sources/Notchquarium/Aquarium/{AquariumScene,BubbleEmitter}.swift`

**Interfaces:**
- Consumes: `VitalsSnapshot`, `FishDiff`.
- Produces:
  ```swift
  final class AquariumScene: SKScene {
      func apply(_ snapshot: VitalsSnapshot) // water level=battery, bubble rate=cpu, tint=memory, fish via diff
  }
  ```

- [ ] **Step 1: Implement** scene: aqua→sky gradient background node, a "water level" crop driven by `batteryFraction`, a `BubbleEmitter` whose `particleBirthRate` scales with `cpuFraction`, and a green tint overlay whose alpha scales with `memoryUsedFraction`.
- [ ] **Step 2: Wire** `AppDelegate` to host an `SKView` in the panel and forward `SystemVitals.snapshot` changes into `scene.apply(_:)`.
- [ ] **Step 3: Run** `swift run` — confirm bubbles rise and water tint reacts (drag CPU up by opening apps).
- [ ] **Step 4: Commit** `feat(aquarium): SpriteKit scene with water + bubbles`.

---

### Task 9: `FishNode` + process binding + tooltips

**Files:**
- Create: `Sources/Notchquarium/Aquarium/FishNode.swift`
- Modify: `Sources/Notchquarium/Aquarium/AquariumScene.swift`

**Interfaces:**
- Produces:
  ```swift
  final class FishNode: SKNode {
      let pid: Int32
      func bind(_ s: ProcessSample) // size/speed/color from cpuPercent
      var appLabel: String          // "Chrome — 41% CPU"
  }
  ```

- [ ] **Step 1: Implement** `FishNode` (drawn fish body via `SKShapeNode`/path, gentle wander action; `bind` maps cpu→scale (0.6–1.6), swim speed, and hue warm=busy). `AquariumScene.apply` consumes `FishDiff.ops` to add/remove/update `FishNode`s.
- [ ] **Step 2: Implement** hover tooltip: on `mouseMoved`, hit-test fish, show a glossy SwiftUI/`NSView` label with `appLabel`.
- [ ] **Step 3: Run** `swift run` — confirm fish appear per top processes, resize with load, tooltip on hover.
- [ ] **Step 4: Commit** `feat(aquarium): fish bound to live processes + tooltips`.

---

### Task 10: Notch states, menu bar, art pass, README

**Files:**
- Create: `Sources/Notchquarium/Window/NotchPanel.swift`, `Sources/Notchquarium/App/MenuBarController.swift`, `Sources/Notchquarium/Aquarium/StatBar.swift`
- Modify: `AppDelegate.swift`, `README.md`

**Interfaces:**
- Consumes: `NotchGeometry`, `AquariumScene`, `SystemVitals`.

- [ ] **Step 1: Implement `NotchPanel`** (borderless, `.nonactivating`, `.floating` level, clear bg, ignores Dock) and state machine: `.ambient` default, hover→`.peek`, click→`.expanded`, mouse-out→collapse after delay, animating frame via `NotchGeometry.tankFrame`.
- [ ] **Step 2: Implement `StatBar`** SwiftUI gel readout (battery %, CPU %, RAM bar) shown in `.expanded`, overlaid on the `SKView`.
- [ ] **Step 3: Implement `MenuBarController`** (`NSStatusItem` with a fish glyph; menu: Show/Hide, Poll rate, Quit).
- [ ] **Step 4: Art pass** — specular highlight gradient on the glass, rounded corners, a light-ray emitter, gravel/plant decorative nodes at the tank floor.
- [ ] **Step 5: Write the full `README.md`** — hero line, GIF placeholder (`docs/demo.gif`), feature list, the vitals mapping table, build/run instructions (`swift run Notchquarium`), requirements (macOS 14+, notch Mac), license.
- [ ] **Step 6: Run** full manual pass through all three states + menu bar.
- [ ] **Step 7: Commit** `feat: notch states, menu bar, stat bar, art pass + README`.

---

## Self-Review

**Spec coverage:** three notch states (T10) ✓; battery/CPU/RAM/process mapping (T3,T5,T8,T9) ✓; fish=processes + tooltips (T9) ✓; SpriteKit rendering (T8,T9) ✓; menu bar + settings (T10) ✓; error handling — no-battery nil path (T2/T3), keep-last-good fish (implicit via diff on empty handled in T9), no-notch fallback (NotchGeometry centers regardless; T10 panel uses it) ✓; testing of vitals mapping/diff/geometry (T2,T3,T6,T7) ✓.

**Placeholder scan:** README GIF is an intentional asset placeholder, not a code placeholder. No "TBD"/"handle edge cases" in code steps.

**Type consistency:** `VitalsSnapshot` fields (`batteryFraction`, `cpuFraction`, `memoryUsedFraction`, `topProcesses`) used identically in T5/T8; `ProcessSample(pid,name,cpuPercent)` consistent across T2/T4/T7/T9; `FishOp`/`FishDiff.ops` consistent T7→T9; `NotchState`/`tankFrame` consistent T6→T10.
