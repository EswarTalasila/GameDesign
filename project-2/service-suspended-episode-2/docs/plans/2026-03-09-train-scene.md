# Train Scene Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a unified train coordinator scene that connects Main Menu -> Train Section 1 -> Dungeon -> Train Section 2 -> Conductor Hub, with grayed-out inventory UI, train audio, and proper NPC management.

**Architecture:** Single `train.tscn` scene with `train.gd` coordinator script (lighter version of `floor.gd`). Narrative hub scenes are stripped of their Player nodes, tiles shifted to positive coordinates, and slotted into section containers. GameState.current_cart_index drives spawn location and NPC visibility. Buffer carts fill visual gaps between sections.

**Tech Stack:** Godot 4.6, GDScript, existing game_ui.tscn / pause_menu.tscn / loading_screen.tscn

---

### Task 1: Copy Train Sound Files Into Godot Project

**Files:**
- Copy: `../../assets/Sounds/Train Sounds.mp3` -> `assets/sounds/train_sounds.mp3`
- Copy: `../../assets/Sounds/Train ambience.mp3` -> `assets/sounds/train_ambience.mp3`
- Copy: `../../assets/Sounds/Train Ambience 2.mp3` -> `assets/sounds/train_ambience_2.mp3`

**Step 1: Copy the 3 sound files into the Godot project sounds folder**

```bash
cp "../../assets/Sounds/Train Sounds.mp3" assets/sounds/train_sounds.mp3
cp "../../assets/Sounds/Train ambience.mp3" assets/sounds/train_ambience.mp3
cp "../../assets/Sounds/Train Ambience 2.mp3" assets/sounds/train_ambience_2.mp3
```

All paths relative to `service-suspended-episode-2/`.

**Step 2: Verify files are in place**

```bash
ls -la assets/sounds/train_*
```

Expected: 3 new mp3 files.

**Step 3: Commit**

```bash
git add assets/sounds/train_sounds.mp3 assets/sounds/train_ambience.mp3 assets/sounds/train_ambience_2.mp3
git commit -m "chore: import train sound files into Godot project"
```

---

### Task 2: Create Train Section Scenes (Strip and Shift Tiles)

**Files:**
- Create: `scenes/train/sections/train_section_1.tscn`
- Create: `scenes/train/sections/train_section_2.tscn`
- Reference: `scenes/train/narrative hub.tscn` (source for section 1)
- Reference: `scenes/train/narrative hub 2.tscn` (source for section 2)

**Step 1: Write a GDScript tool to parse and shift tile data**

Create `tools/shift_train_tiles.gd` — an @tool script that:
1. Opens each narrative hub .tscn
2. Finds all TileMapLayer nodes
3. Decodes the PackedByteArray tile_map_data
4. Finds the minimum x,y cell coordinates across all layers
5. Shifts all cells so minimum is at (0, 0)
6. Re-encodes the tile_map_data
7. Removes the Player node from the scene
8. Saves as new section scene files

The tile_map_data format in Godot 4 is: each cell is 12 bytes:
- bytes 0-1: x coordinate (int16 little-endian)
- bytes 2-3: y coordinate (int16 little-endian)
- bytes 4-5: source_id (int16 LE)
- bytes 6-7: atlas_x (int16 LE)
- bytes 8-9: atlas_y (int16 LE)
- bytes 10-11: alternative_tile (int16 LE)

Write the tool script:

```gdscript
@tool
extends EditorScript

func _run() -> void:
    _shift_scene("res://scenes/train/narrative hub.tscn", "res://scenes/train/sections/train_section_1.tscn")
    _shift_scene("res://scenes/train/narrative hub 2.tscn", "res://scenes/train/sections/train_section_2.tscn")
    print("Done! Saved shifted section scenes.")

func _shift_scene(source_path: String, dest_path: String) -> void:
    var scene = load(source_path) as PackedScene
    var root = scene.instantiate()

    # Remove Player node if present
    var player = root.get_node_or_null("Player")
    if player:
        root.remove_child(player)
        player.queue_free()

    # Find all TileMapLayers and collect minimum coordinates
    var all_tilemaps: Array[TileMapLayer] = []
    _find_tilemaps(root, all_tilemaps)

    var min_x: int = 999999
    var min_y: int = 999999
    for tm in all_tilemaps:
        for cell in tm.get_used_cells():
            min_x = mini(min_x, cell.x)
            min_y = mini(min_y, cell.y)

    if min_x == 999999:
        print("No tiles found in ", source_path)
        return

    # Shift all tiles so minimum is at (0, 0)
    var offset = Vector2i(-min_x, -min_y)
    for tm in all_tilemaps:
        var cells_data: Array[Dictionary] = []
        for cell in tm.get_used_cells():
            cells_data.append({
                "cell": cell,
                "source": tm.get_cell_source_id(cell),
                "atlas": tm.get_cell_atlas_coords(cell),
                "alt": tm.get_cell_alternative_tile(cell),
            })
        tm.clear()
        for d in cells_data:
            tm.set_cell(d.cell + offset, d.source, d.atlas, d.alt)

    # Save as new packed scene
    var new_scene = PackedScene.new()
    new_scene.pack(root)
    ResourceSaver.save(new_scene, dest_path)
    root.queue_free()
    print("Saved: ", dest_path, " (shifted by ", offset, ")")

func _find_tilemaps(node: Node, result: Array[TileMapLayer]) -> void:
    if node is TileMapLayer:
        result.append(node)
    for child in node.get_children():
        _find_tilemaps(child, result)
```

**Step 2: Run the tool in Godot editor**

Open Godot, go to Script Editor, open `tools/shift_train_tiles.gd`, click File > Run (or Ctrl+Shift+X).

**Step 3: Verify the new section scenes exist**

```bash
ls -la scenes/train/sections/
```

Expected: `train_section_1.tscn` and `train_section_2.tscn`.

**Step 4: Open each scene in Godot and verify tiles are in positive quadrant**

Visual check — tiles should start at (0,0) or near it.

**Step 5: Commit**

```bash
git add tools/shift_train_tiles.gd scenes/train/sections/
git commit -m "feat: create train section scenes with tiles shifted to positive quadrant"
```

---

### Task 3: Write train.gd Coordinator Script

**Files:**
- Create: `scenes/train/train.gd`

**Step 1: Write the train coordinator script**

```gdscript
extends Node2D

# Train coordinator — manages train sections, NPC visibility,
# connector interactions, UI dimming, audio, and pause menu.
# Flow: Main Menu -> Section 1 -> Dungeon -> Section 2 -> Conductor Hub

# --- Audio ---
var _train_sounds_stream = preload("res://assets/sounds/train_sounds.mp3")
var _ambience_stream = preload("res://assets/sounds/train_ambience.mp3")
var _ambience_stream_2 = preload("res://assets/sounds/train_ambience_2.mp3")

# --- Cursor ---
var _cursor_default = preload("res://assets/ui/cursor/frame_1.png")
var _cursor_clicked = preload("res://assets/ui/cursor/frame_0.png")

# --- Pause ---
var _pause_normal = preload("res://assets/ui/buttons/play_pause/pause_normal.png")
var _pause_pressed = preload("res://assets/ui/buttons/play_pause/pause_pressed.png")
var _play_normal = preload("res://assets/ui/buttons/play_pause/play_normal.png")

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var cursor_sprite: Sprite2D = $GameUI/CursorLayer/CursorSprite
@onready var punch_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PunchSlot
@onready var ticket_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/TicketSlot
@onready var key_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/KeySlot
@onready var special_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/SpecialSlot
@onready var pause_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PauseSlot

# --- Section containers ---
@onready var section_1_container: Node2D = $GameWorld/Sections/Section1
@onready var section_2_container: Node2D = $GameWorld/Sections/Section2

# --- State ---
var _paused: bool = false

# --- Spawn points (set these to the checkpoint position for each section) ---
@export var section_1_spawn: Vector2 = Vector2(48, 48)
@export var section_2_spawn: Vector2 = Vector2(400, 48)


func _ready() -> void:
    _disable_autoload_cursor()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

    # Cursor setup
    cursor_sprite.texture = _cursor_default
    cursor_sprite.centered = false
    cursor_sprite.scale = Vector2(1, 1)
    cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    # Dim inventory slots (visible but grayed out, unclickable)
    var dim_color = Color(1, 1, 1, 0.4)
    punch_slot.modulate = dim_color
    ticket_slot.modulate = dim_color
    key_slot.modulate = dim_color
    special_slot.modulate = dim_color

    # Determine which section to spawn in based on cart_index
    if GameState.current_cart_index >= 1:
        # Returned from dungeon — spawn in section 2
        player.global_position = section_2_spawn
        GameState.set_checkpoint(section_2_spawn, "section_2")
        # Remove Lady in Red from section 1
        _remove_npc_from_section(section_1_container)
    else:
        # Fresh start — spawn in section 1
        player.global_position = section_1_spawn
        GameState.set_checkpoint(section_1_spawn, "section_1")
        # Remove Lady in Red from section 2
        _remove_npc_from_section(section_2_container)

    # Connect connector interactions
    _setup_connectors()

    # Audio — train sounds (quiet, looping)
    var train_sfx = AudioStreamPlayer.new()
    train_sfx.stream = _train_sounds_stream
    train_sfx.name = "TrainSounds"
    train_sfx.volume_db = -18.0
    add_child(train_sfx)
    train_sfx.finished.connect(train_sfx.play)
    train_sfx.play()

    # Audio — random ambience (looping)
    var ambience = AudioStreamPlayer.new()
    ambience.stream = [_ambience_stream, _ambience_stream_2].pick_random()
    ambience.name = "TrainAmbience"
    add_child(ambience)
    ambience.finished.connect(ambience.play)
    ambience.play()


func _remove_npc_from_section(section_container: Node2D) -> void:
    if section_container.get_child_count() == 0:
        return
    var section = section_container.get_child(0)
    for child in section.get_children():
        if child is CharacterBody2D and child.has_method("_start_dialogue"):
            child.queue_free()


func _setup_connectors() -> void:
    var connectors = $Connectors
    for child in connectors.get_children():
        if child is Area2D:
            child.body_entered.connect(_on_connector_entered.bind(child))
            child.body_exited.connect(_on_connector_exited.bind(child))


var _near_connector: Area2D = null
var _connector_prompt: Node = null

func _on_connector_entered(body: Node2D, connector: Area2D) -> void:
    if body == player:
        _near_connector = connector
        # Show press E prompt
        var prompt = connector.get_node_or_null("PressEPrompt")
        if prompt:
            prompt.visible = true
            _connector_prompt = prompt

func _on_connector_exited(body: Node2D, connector: Area2D) -> void:
    if body == player and _near_connector == connector:
        _near_connector = null
        if _connector_prompt:
            _connector_prompt.visible = false
            _connector_prompt = null


func _input(event: InputEvent) -> void:
    if _paused:
        return

    # Cursor click feedback
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        cursor_sprite.texture = _cursor_clicked if event.pressed else _cursor_default

    # Press E at connector
    if event.is_action_pressed("interact") and _near_connector:
        _activate_connector(_near_connector)

    # Pause menu (Escape) — only pause slot is clickable
    if event.is_action_pressed("ui_cancel"):
        _open_pause_menu()

    # Pause slot click
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var click = get_viewport().get_mouse_position()
        if _is_click_on_slot(click, pause_slot):
            _on_pause_slot_pressed()


func _activate_connector(connector: Area2D) -> void:
    var target = connector.get_meta("target", "dungeon")
    player.set_physics_process(false)

    if target == "dungeon":
        GameState.start_dungeon(0, "standard", 5)
        var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
        get_tree().root.add_child(loading)
        loading.transition_to("res://scenes/floors/floor_1/floor_1.tscn")
    elif target == "conductor":
        var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
        get_tree().root.add_child(loading)
        loading.transition_to("res://scenes/train/conductor_hub.tscn")


# --- Pause menu ---

func _is_click_on_slot(click_pos: Vector2, slot: Sprite2D) -> bool:
    var slot_screen = slot.get_global_transform_with_canvas().origin
    return click_pos.distance_to(slot_screen) < 40.0

func _on_pause_slot_pressed() -> void:
    pause_slot.texture = _pause_pressed
    await get_tree().create_timer(0.1).timeout
    _open_pause_menu()

func _open_pause_menu() -> void:
    _paused = true
    pause_slot.texture = _play_normal
    get_tree().paused = true
    var menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
    get_tree().root.add_child(menu)
    menu.resume_requested.connect(_on_pause_resume.bind(menu))
    menu.restart_requested.connect(_on_pause_restart.bind(menu))
    menu.quit_requested.connect(_on_pause_quit.bind(menu))

func _on_pause_resume(menu: CanvasLayer) -> void:
    menu.queue_free()
    get_tree().paused = false
    _paused = false
    pause_slot.texture = _pause_normal

func _on_pause_restart(menu: CanvasLayer) -> void:
    menu.queue_free()
    get_tree().paused = false
    _paused = false
    var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
    get_tree().root.add_child(loading)
    loading.transition_to("res://scenes/train/train.tscn")

func _on_pause_quit(menu: CanvasLayer) -> void:
    menu.queue_free()
    get_tree().paused = false
    get_tree().quit()


# --- Cursor management (same as floor.gd) ---

func _disable_autoload_cursor() -> void:
    if has_node("/root/CustomCursor"):
        var cc = get_node("/root/CustomCursor")
        cc.set_process(false)
        cc.set_process_input(false)
        for child in cc.get_children():
            if child is CanvasLayer:
                for grandchild in child.get_children():
                    if grandchild is Sprite2D:
                        grandchild.visible = false

func _exit_tree() -> void:
    if has_node("/root/CustomCursor"):
        var cc = get_node("/root/CustomCursor")
        cc.set_process(true)
        cc.set_process_input(true)
        for child in cc.get_children():
            if child is CanvasLayer:
                for grandchild in child.get_children():
                    if grandchild is Sprite2D:
                        grandchild.visible = true
```

**Step 2: Commit**

```bash
git add scenes/train/train.gd
git commit -m "feat: add train coordinator script"
```

---

### Task 4: Build train.tscn Scene in Editor

**Files:**
- Create: `scenes/train/train.tscn` (manual scene assembly in Godot editor)

This task must be done in the Godot editor. Create the scene with this structure:

```
Train (Node2D) — script: train.gd
├── GameWorld (Node2D, y_sort_enabled = true)
│   ├── Sections (Node2D)
│   │   ├── Section1 (Node2D) — contains train_section_1.tscn instance
│   │   ├── BufferCarts (Node2D) — empty cart tiles between sections
│   │   └── Section2 (Node2D) — contains train_section_2.tscn instance, offset right
│   └── Player (instance of player.tscn)
├── Boundaries (Node2D)
│   ├── Section1 (Area2D + CollisionShape2D covering section 1 area)
│   └── Section2 (Area2D + CollisionShape2D covering section 2 area)
├── Connectors (Node2D)
│   ├── DungeonConnector (Area2D) — between section 1 and buffer/section 2
│   │   ├── CollisionShape2D
│   │   └── PressEPrompt (instance of press_e_prompt.tscn, visible = false)
│   │   Meta: target = "dungeon"
│   └── ConductorConnector (Area2D) — at end of section 2
│       ├── CollisionShape2D
│       └── PressEPrompt (instance of press_e_prompt.tscn, visible = false)
│       Meta: target = "conductor"
└── GameUI (instance of game_ui.tscn)
```

**Key setup steps in editor:**
1. Add train.gd as the root script
2. Instance train_section_1.tscn under Section1 container
3. Instance train_section_2.tscn under Section2 container, position it to the right with buffer space
4. Paint buffer cart tiles between sections using the train tileset
5. Place connector Area2Ds at the cart boundaries
6. Add PressEPrompt (from `scenes/ui/press_e_prompt.tscn`) as child of each connector, set visible = false
7. Set metadata on connectors: DungeonConnector meta "target" = "dungeon", ConductorConnector meta "target" = "conductor"
8. Set the export vars section_1_spawn and section_2_spawn to the desired player positions
9. Instance game_ui.tscn as GameUI child

**Step 2: Test in editor**

Run the train scene with F6 to verify:
- Player spawns in section 1
- Camera follows player
- Inventory slots are dimmed
- Train sounds play
- Press E prompt appears near connectors

**Step 3: Commit**

```bash
git add scenes/train/train.tscn
git commit -m "feat: build train coordinator scene"
```

---

### Task 5: Wire Game Flow — Main Menu -> Train -> Dungeon -> Train

**Files:**
- Modify: `scenes/ui/main_menu.gd:71`
- Modify: `scenes/doors/exit_door.gd:26`
- Modify: `scenes/doors/exit_frame.gd:55` (if exit_frame is used)
- Modify: `scenes/floors/shared/floor.gd:687-690`
- Modify: `project.godot:14`

**Step 1: Update main_menu.gd to load train instead of floor_1**

In `scenes/ui/main_menu.gd`, line 71, change:
```gdscript
# OLD:
get_tree().change_scene_to_file("res://scenes/floors/floor_1/floor_1.tscn")
# NEW:
get_tree().change_scene_to_file("res://scenes/train/train.tscn")
```

**Step 2: Update exit_door.gd to return to train**

In `scenes/doors/exit_door.gd`, line 26, change:
```gdscript
# OLD:
loading.transition_to("res://scenes/rooms/train_cart_hub.tscn")
# NEW:
loading.transition_to("res://scenes/train/train.tscn")
```

**Step 3: Update floor.gd _on_exit_door_used to go to train**

In `scenes/floors/shared/floor.gd`, replace `_on_exit_door_used` (lines 675-690):
```gdscript
func _on_exit_door_used() -> void:
    is_animating = true
    player.set_physics_process(false)
    player.visible = false
    player.collision_layer = 0
    player.collision_mask = 0
    GameState.complete_dungeon()
    var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
    get_tree().root.add_child(loading_screen)
    loading_screen.transition_to("res://scenes/train/train.tscn")
```

Key change: calls `GameState.complete_dungeon()` (increments cart_index) and goes to train.tscn instead of reloading the same floor.

**Step 4: Update project.godot main scene to main menu**

In `project.godot`, line 14, change:
```
run/main_scene="res://scenes/ui/main_menu.tscn"
```

**Step 5: Commit**

```bash
git add scenes/ui/main_menu.gd scenes/doors/exit_door.gd scenes/floors/shared/floor.gd project.godot
git commit -m "feat: wire game flow Main Menu -> Train -> Dungeon -> Train"
```

---

### Task 6: Clean Up Debug Prints and Old References

**Files:**
- Modify: `scenes/npc/red_coat_lady.gd:25,30` (remove debug prints)
- Modify: `scenes/rooms/train_cart_hub.gd:68` (fix old dungeon.tscn reference, or mark deprecated)

**Step 1: Remove debug prints from red_coat_lady.gd**

In `scenes/npc/red_coat_lady.gd`:

Line 25 — remove:
```gdscript
print("E pressed! player_in_range = ", player_in_range)
```

Line 30 — remove:
```gdscript
print("Body entered: ", body.name, " Groups: ", body.get_groups())
```

**Step 2: Fix train_cart_hub.gd reference (if keeping scene)**

In `scenes/rooms/train_cart_hub.gd`, line 68, change:
```gdscript
# OLD:
loading.transition_to("res://scenes/dungeon/dungeon.tscn")
# NEW:
loading.transition_to("res://scenes/floors/floor_1/floor_1.tscn")
```

This scene is no longer in the main flow but fixing the reference prevents errors if someone opens it.

**Step 3: Commit**

```bash
git add scenes/npc/red_coat_lady.gd scenes/rooms/train_cart_hub.gd
git commit -m "fix: remove debug prints, fix old dungeon.tscn reference"
```

---

### Task 7: Integration Test — Full Game Flow

**No files to modify — testing only.**

**Step 1: Delete .godot/ folder and reopen project**

This fixes UID cache issues from the teammate's pull.

```bash
rm -rf .godot/
```

Then reopen the project in Godot. Wait for import to complete.

**Step 2: Set main scene if needed**

Project > Project Settings > General > Application > Run > Main Scene = `res://scenes/ui/main_menu.tscn`

**Step 3: Play through the full flow**

Test checklist:
- [ ] Main menu loads
- [ ] Play button loads train.tscn
- [ ] Player spawns in Section 1
- [ ] Inventory slots are dimmed and unclickable
- [ ] Train sounds play (quiet)
- [ ] Train ambience plays
- [ ] Lady in Red is in Section 1, NOT in Section 2
- [ ] Can talk to Lady in Red (Lady_in_red.dialogue)
- [ ] Press E prompt appears at dungeon connector
- [ ] Press E loads floor_1 via loading screen
- [ ] Dungeon plays normally
- [ ] Exit door calls complete_dungeon() and loads train.tscn
- [ ] Player spawns in Section 2
- [ ] Lady in Red is in Section 2, NOT in Section 1
- [ ] Can talk to Lady in Red (Lady_in_red_2.dialogue)
- [ ] Press E at conductor connector loads conductor hub
- [ ] Pause menu works (Resume, Restart, Quit)
- [ ] Restart reloads train scene to current section
- [ ] Escape opens pause menu
