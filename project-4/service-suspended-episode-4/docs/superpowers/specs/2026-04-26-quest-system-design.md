---
name: Quest System Design
description: Design spec for QuestManager autoload and quest widget UI for Service Suspended Episode 4
type: spec
date: 2026-04-26
---

# Quest System Design

## Overview

A lightweight, signal-driven quest system consisting of a `QuestManager` autoload and a `QuestWidget` HUD element. The system tracks a single active primary objective with nested sub-objectives (max depth 2), displays them on screen with animated completion feedback, and resets alongside `GameState` on death.

---

## Data Model

### QuestObjective (inner class in QuestManager)

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique key (e.g. `"explore"`, `"free_cat"`) |
| `text` | `String` | Display text shown in the widget |
| `children` | `Array[QuestObjective]` | Sub-objectives. Max depth 2 — children never have their own children. |
| `completed` | `bool` | True once `complete(id)` is called |
| `_completing` | `bool` | Transient flag, true while the fade-out animation is in progress |

### QuestManager State

- `primary: QuestObjective` — the single active primary objective. `null` when no objective is set.
- Completion timer: `1.2s` delay between marking `completed = true` and actually removing the objective. This gives the widget time to play the strikethrough + fade-out animation.

---

## QuestManager Autoload

**File:** `scripts/quest_manager.gd`  
**Autoload name:** `QuestManager`

### Signals

| Signal | When emitted |
|---|---|
| `objectives_changed` | After any structural change (add, remove, set_primary) |
| `objective_completed(id: String)` | When `complete(id)` is called — triggers widget animation |

### Public API

```gdscript
QuestManager.set_primary(id: String, text: String)
# Sets the top-level objective. Replaces any existing primary (and its children).

QuestManager.add_sub(id: String, text: String, parent_id: String)
# Adds a sub-objective under the objective with the given parent_id.
# parent_id can be the primary id (depth 1) or a depth-1 sub id (depth 2).
# Silently ignored if parent_id is not found or depth limit is exceeded.

QuestManager.complete(id: String)
# Marks the objective completed. Emits objective_completed(id).
# After 1.2s, removes the objective AND all its children, then emits objectives_changed.
# If the completed objective is the primary, primary becomes null after removal.

QuestManager.reset()
# Clears all objectives. Called by GameState.reset().
```

### Reset Integration

One line added to `GameState.reset()`:
```gdscript
QuestManager.reset()
```

---

## Quest Widget (HUD)

### Files
- `scenes/ui/quest_widget.tscn` + `scenes/ui/quest_widget.gd`
- `scenes/ui/objective_row.tscn` + `scenes/ui/objective_row.gd`

### Scene Structure

```
QuestWidget (PanelContainer)
  └─ VBoxContainer
       ├─ Header (Label: "Objectives")
       └─ ObjectiveList (VBoxContainer)  ← dynamically populated at runtime
```

### Visual Style
- Semi-transparent dark background on the `PanelContainer` (black at ~50% alpha)
- White text throughout
- Widget is hidden when `QuestManager.primary == null`

### ObjectiveRow Scene

```
ObjectiveRow (HBoxContainer)
  ├─ Indent (Control, min_size.x varies by depth)
  ├─ Checkbox (TextureRect — empty square or checkmark)
  └─ TextLabel (RichTextLabel — supports strikethrough via BBCode)
```

Depth mapping:
- Primary objective: 0px indent
- Depth-1 sub: 12px indent
- Depth-2 sub: 24px indent

### Widget Behavior

1. On `QuestManager.objectives_changed` → fully rebuild `ObjectiveList` from current state
2. On `QuestManager.objective_completed(id)` → find the matching row, apply `[s]strikethrough[/s]` styling, then run a `Tween` fade (alpha 1.0 → 0.0 over 1.0s). Row is freed after the tween; `objectives_changed` fires immediately after removal so remaining rows shift up cleanly.
3. Widget added to `jungle_game_ui.tscn` alongside existing HUD elements.

---

## Integration Points

All integration is explicit — one or two `QuestManager.*` calls at the relevant event site.

### Dungeon start — `variant_coordinator.gd` `_ready()`
```gdscript
QuestManager.set_primary("explore", "Explore")
```

### Campfire first interaction — `campfire.gd` after `await DialogueManager.dialogue_ended`
```gdscript
QuestManager.complete("explore")
QuestManager.set_primary("escape", "Find a way to escape the dungeon")
QuestManager.add_sub("use_clock", "Use the clock to travel to Variant 2", "escape")
```

### Clock variant travel — `variant_coordinator.gd` `_on_clock_variant_selected()`
```gdscript
QuestManager.complete("use_clock")
QuestManager.add_sub("explore_v2", "Explore Variant 2", "escape")
```

### Cat narrative — `cat_npc.gd` at relevant dialogue/interaction points
```gdscript
# On cat found:
QuestManager.complete("explore_v2")
QuestManager.add_sub("find_cat", "Find the cat", "escape")

# On approaching cat (locked):
QuestManager.complete("find_cat")
QuestManager.add_sub("free_cat", "Free the cat", "escape")
QuestManager.add_sub("find_key", "Find the key", "free_cat")

# On key collected:
QuestManager.complete("find_key")
QuestManager.add_sub("return_cat", "Return to the cat", "free_cat")

# On cat freed:
QuestManager.complete("free_cat")
QuestManager.add_sub("follow_cat", "Follow the cat", "escape")

# On following cat to destination:
QuestManager.complete("follow_cat")
QuestManager.add_sub("talk_cat", "Talk to the cat", "escape")

# On talking to cat:
QuestManager.complete("talk_cat")
QuestManager.add_sub("find_map_pieces", "Find the map pieces", "escape")

# On all map pieces collected:
QuestManager.complete("find_map_pieces")
QuestManager.add_sub("travel_v3", "Travel to Variant 3", "escape")
```
> Note: exact trigger points in `cat_npc.gd` will be confirmed during implementation based on the dialogue/interaction flow.

---

## Files to Create

| File | Purpose |
|---|---|
| `scripts/quest_manager.gd` | QuestManager autoload |
| `scenes/ui/quest_widget.gd` | Widget controller |
| `scenes/ui/quest_widget.tscn` | Widget scene |
| `scenes/ui/objective_row.gd` | Single row controller |
| `scenes/ui/objective_row.tscn` | Single row scene |

## Files to Modify

| File | Change |
|---|---|
| `scripts/game_state.gd` | Add `QuestManager.reset()` call in `reset()` |
| `scenes/jungle/variant_coordinator.gd` | Add `set_primary("explore", ...)` in `_ready()` and `complete/add_sub` in `_on_clock_variant_selected()` |
| `scenes/interactables/campfire.gd` | Add quest calls after dialogue in `_play_intro_and_ignite()` |
| `scenes/npc/cat_npc.gd` | Add quest calls at relevant interaction/dialogue points |
| `scenes/ui/jungle_game_ui.tscn` | Add `QuestWidget` node to HUD |
| `project.godot` | Register `QuestManager` as autoload |
