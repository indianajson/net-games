## Net-Games UI / Dialogue / Input Overhaul

Author: Whynchu (contributor)
Date: 2024-06-15  
Scope: Displayer, Dialogue, Input, Timers, TextDisplay  
Compatibility: Backwards-compatible (additive where possible)

### Summary
This change refactors and stabilizes the Net-Games UI stack by introducing a unified Displayer API, a robust Dialogue system, and a sticky, swallow-aware Input helper. The primary goals are to eliminate softlocks, input carry bugs, sprite collisions, and brittle cross-module dependencies while preserving existing scripts and behaviors.

The work is based on real gameplay stress tests including Simon Says, NPC dialogue chains, marquees, and timers.

---

### Displayer API (Unified Front Door)
- Introduced Displayer as a single facade for:
  - Text, text boxes, and marquee rendering
  - Timers and countdowns
  - Font rendering
  - Scrolling text and sprite lists
- Subsystems are loaded with protected calls and validated at runtime.
- One failing subsystem no longer crashes server startup.
- Added guarded subsystem access with explicit error logging.
- Additive API compatibility:
  - camelCase and snake_case variants supported for key methods.

Rationale: Prevent hard crashes, allow safer refactors, and centralize UI behavior behind a stable interface.

---

### Dialogue System Rewrite
- Dialogue is now a per-player stateful system with explicit lifecycle management.
- Input locking and unlocking is guarded and cannot leave players stuck.
- Added input swallow windows to prevent carry-confirm bugs when:
  - opening dialogue
  - entering waiting state
  - closing dialogue
- Dialogue progression is tick-driven and state-aware.
- Rich UI configuration supported per dialogue:
  - textbox style and backdrop
  - typing speed and sound effects
  - confirm behavior during typing
  - mugshots as first-class UI elements

Rationale: Fix skipped lines, infinite mouth-flap loops, confirm spam, and input softlocks.

---

### Input Helper (Sticky and Edge-Safe)
- Added a centralized Input helper that:
  - Tracks edge presses reliably
  - Handles missing Pressed events from client input
  - Supports swallowing input for short, controlled windows
- Listener attachment is guarded to prevent duplicate registration.
- Debug utilities added to inspect real client input names and states.

Rationale: Prevent softlocks and inconsistent confirm or cancel behavior across systems.

---

### TextDisplay and TextBox Improvements
- Backdrops are now lazily allocated and only created when used.
- Text boxes support:
  - wait-for-confirm
  - auto-advance
  - confirm-during-typing toggle
- Typing sound effects are auto-provisioned per player.
- Mugshots are integrated into the textbox lifecycle.
- Explicit cleanup paths prevent lingering sprites and UI artifacts.

Rationale: Fix backdrop initialization errors, sprite leaks, and inconsistent textbox behavior.

---

### Timer System and Timer Display Separation
- TimerSystem handles timer logic and emits events only.
- TimerDisplay listens for events and renders output using FontSystem.
- Corrected player versus global timer event signatures.
- Stable sprite ID ranges prevent UI collisions.
- Late-join synchronization for global timers is preserved.

Rationale: Improve correctness, reduce duplication, and prevent timer desynchronization.

---

### Notes for Maintainers
- Some games such as Simon Says rely on a games compatibility layer
  (for example freeze_player and move_frozen_player).
  Missing helpers will result in runtime errors but are not logic regressions.
- No breaking API removals were made. All changes are additive or guarded.

---

### TLDR
This change makes Net-Games more stable, easier to extend, and more consistent under real gameplay conditions. It replaces fragile glue logic with explicit systems, clear lifecycles, and defensive input handling.
