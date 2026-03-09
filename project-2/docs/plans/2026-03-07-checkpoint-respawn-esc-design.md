# Checkpoint, Respawn & ESC Cancellation Design

## Checkpoint System

### State (GameState)
- `checkpoint_position: Vector2` — world position to respawn at
- `checkpoint_section: String` — which section the checkpoint is in
- `set_checkpoint(pos: Vector2, section: String)` — updates both, emits `checkpoint_set` signal

### When Checkpoints Are Set
- On floor entry (`floor.gd::_ready`) — player spawn position
- On section transition — Area2D trigger zones at section entrances (zones added when static connector pieces between sections are designed)

### Saving Icon
- Animated sprite on UI layer (CanvasLayer)
- Plays corner animation when `checkpoint_set` fires
- Asset exported from Aseprite by user

## Respawn (Costs 1 Ticket)

### Behavior
- Does NOT reload the scene
- Deducts 1 ticket from `tickets_collected`
- Teleports player to `checkpoint_position`
- Re-enables player: reset dead state, restore physics/visibility/collision
- All entities stay as-is: enemies, items, doors, chests, levers — no state reset
- Respawn button disabled if player has 0 tickets

### Changes to floor.gd
- `_on_death_respawn()` replaces scene reload with:
  1. Deduct ticket
  2. Move player to `GameState.checkpoint_position`
  3. Re-enable player node (visible, process, collision)
  4. Dismiss death screen

## Reload (Free)

### Behavior — unchanged
- Full scene reload
- Re-randomize section variants
- Reset `tickets_collected` and `keys_collected` to 0
- All entities reset to initial state

## ESC Cancellation Stack

### Priority (highest to lowest)
1. Key cursor mode active → cancel key cursor, restore appropriate cursor (punch if ticket floating, else default)
2. Floating ticket visible (punch mode) → dismiss ticket (fly-out animation), cancel punch mode, restore default cursor
3. Nothing active → no action (future: pause menu)

### Two-Step Scenario
- Key cursor active AND floating ticket on screen
- First ESC: cancels key cursor only, ticket still floating
- Second ESC: dismisses floating ticket, returns to default

### Additional Cancel Trigger
- Clicking the ticket icon while a ticket is floating → same as ESC step 2 (dismiss ticket, cancel punch)

### Implementation in floor.gd::_input()
```
if Input.is_action_just_pressed("ui_cancel"):
    if GameState.key_mode:
        GameState.set_key_mode(false)
        # restore cursor: punch if ticket floating, else default
    elif _ticket_floating:
        _cancel_floating_ticket()
        # fly-out animation, restore default cursor
```

## Asset Integration (User-Provided)
- Saving icon: animated Aseprite export → UI layer scene
- Death screen: updated scene with new font (replace existing death_screen.tscn)
- Loading screen: updated scene (replace existing)

## Out of Scope
- Static connector pieces between sections (layout not designed yet)
- Section transition Area2D placement (checkpoint API ready, zones added later)
- Pause menu (ESC when nothing active — future feature)
