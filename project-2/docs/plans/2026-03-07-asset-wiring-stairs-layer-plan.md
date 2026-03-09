# Asset Wiring & Stairs Layer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire updated death/loading screen frames, create saving icon scene, and add Stairs TileMapLayer to all 24 section scenes.

**Architecture:** Four independent tasks — frame swaps for death/loading screens, a new saving icon AnimatedSprite2D scene wired to the checkpoint signal, and a script to inject a Stairs TileMapLayer node into all section .tscn files.

**Tech Stack:** Godot 4.6, GDScript, .tscn text format editing

---

### Task 1: Update Death Screen Frames

**Files:**
- Modify: `service-suspended-episode-2/scenes/ui/death_screen.tscn`

The .tscn currently references `assets/ui/death_screen/frame_0.png` through `frame_9.png` (old font, Feb 25). New frames with updated font are `death_screen1.png` through `death_screen10.png` (Mar 7).

**Step 1: Update ext_resource paths in death_screen.tscn**

Replace 10 ext_resource lines that reference `frame_N.png` with `death_screenN+1.png`:

```
frame_0.png → death_screen1.png
frame_1.png → death_screen2.png
frame_2.png → death_screen3.png
frame_3.png → death_screen4.png
frame_4.png → death_screen5.png
frame_5.png → death_screen6.png
frame_6.png → death_screen7.png
frame_7.png → death_screen8.png
frame_8.png → death_screen9.png
frame_9.png → death_screen10.png
```

Keep the existing ext_resource IDs (`2_d0` through `11_d9`) and UIDs — only change the path strings. Godot will regenerate UIDs on next load if needed.

**Step 2: Delete old frame files**

```bash
rm service-suspended-episode-2/assets/ui/death_screen/frame_*.png
rm service-suspended-episode-2/assets/ui/death_screen/frame_*.png.import
```

**Step 3: Commit**

```bash
git add scenes/ui/death_screen.tscn assets/ui/death_screen/
git commit -m "feat: update death screen to use new font frames"
```

---

### Task 2: Update Loading Screen Frames

**Files:**
- Modify: `service-suspended-episode-2/assets/ui/loading_screen/frame_0.png` through `frame_9.png`

The .tscn references root-level `frame_0-9.png` (Feb 25, old font). Updated frames are in the `frames/` subdirectory (Mar 7, new font). Copy new over old so the .tscn paths stay intact.

**Step 1: Copy updated frames over old ones**

```bash
cd service-suspended-episode-2/assets/ui/loading_screen
for i in $(seq 0 9); do cp frames/frame_$i.png frame_$i.png; done
```

**Step 2: Commit**

```bash
git add assets/ui/loading_screen/
git commit -m "feat: update loading screen frames with new font"
```

---

### Task 3: Create Saving Icon Scene

**Files:**
- Create: `service-suspended-episode-2/scenes/ui/saving_icon.tscn`
- Create: `service-suspended-episode-2/scenes/ui/saving_icon.gd`
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd:35` (add preload)
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd:358-360` (replace TODO)

**Step 1: Create saving_icon.gd**

```gdscript
extends AnimatedSprite2D

# Plays the saving animation once, then fades out and self-destructs.

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	# Bottom-right, inset by one icon width + padding
	position = Vector2(viewport_size.x - 140, viewport_size.y - 140)
	scale = Vector2(2, 2)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = Color(1, 1, 1, 0)

	# Build SpriteFrames from individual frame PNGs
	var frames = SpriteFrames.new()
	frames.add_animation("save")
	frames.set_animation_speed("save", 10.0)
	frames.set_animation_loop("save", false)
	for i in range(10):
		var tex = load("res://assets/ui/saving_icon/frames/frame_%d.png" % i)
		frames.add_frame("save", tex)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	sprite_frames = frames

	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): play("save"))

	animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	# Hold for a moment then fade out
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
```

**Step 2: Create saving_icon.tscn**

Minimal scene — just the root AnimatedSprite2D with the script attached:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/ui/saving_icon.gd" id="1_script"]

[node name="SavingIcon" type="AnimatedSprite2D"]
script = ExtResource("1_script")
```

**Step 3: Wire into floor.gd**

Add preload near line 35 (after `_burn_shader`):

```gdscript
var _saving_icon_scene = preload("res://scenes/ui/saving_icon.tscn")
```

Replace `_on_checkpoint_set` (lines 358-360):

```gdscript
func _on_checkpoint_set(_pos: Vector2, _section: String) -> void:
	var icon = _saving_icon_scene.instantiate()
	$UILayer.add_child(icon)
```

**Step 4: Commit**

```bash
git add scenes/ui/saving_icon.gd scenes/ui/saving_icon.tscn scenes/floors/shared/floor.gd
git commit -m "feat: add saving icon animation on checkpoint set"
```

---

### Task 4: Add Stairs TileMapLayer to All Section Scenes

**Files:**
- Modify: all 24 `section_*_v*.tscn` files under `scenes/floors/floor_1/sections/` and `scenes/floors/floor_2/sections/`

Each section .tscn has this node order:
```
SectionX_VN (root)
  Terrain
    Furniture
    EnemyMarkers
    Items
  Overhead
  Doors
  Walls
  SideWalls
```

We need to add a "Stairs" TileMapLayer node after Walls but before SideWalls. It uses the same tileset as Terrain (ext_resource for `dungeon_terrain.tres`), with `y_sort_enabled = true`.

**Step 1: Write a bash script to inject the Stairs node into all 24 .tscn files**

The injection point: insert the Stairs node block right before the `[node name="SideWalls"` line. The Stairs node needs to reference the same tileset ext_resource ID as Terrain (varies per file — look for the `dungeon_terrain.tres` ext_resource ID).

```bash
cd service-suspended-episode-2
for f in $(find scenes/floors -name "section_*_v*.tscn"); do
  # Find the ext_resource ID for dungeon_terrain.tres
  TILESET_ID=$(grep 'dungeon_terrain.tres' "$f" | head -1 | sed 's/.*id="\([^"]*\)".*/\1/')

  # Find the root node name (first [node ...] line)
  ROOT_NAME=$(grep -m1 '^\[node name=' "$f" | sed 's/.*name="\([^"]*\)".*/\1/')

  # Insert Stairs node before SideWalls
  sed -i '' "/^\[node name=\"SideWalls\"/i\\
\\
[node name=\"Stairs\" type=\"TileMapLayer\" parent=\".\"]\\
y_sort_enabled = true\\
tile_set = ExtResource(\"${TILESET_ID}\")
" "$f"
done
```

**Step 2: Verify a sample file**

```bash
grep -A3 "Stairs" scenes/floors/floor_1/sections/section_a/section_a_v1.tscn
```

Expected output:
```
[node name="Stairs" type="TileMapLayer" parent="."]
y_sort_enabled = true
tile_set = ExtResource("2_dnqhi")
```

**Step 3: Commit**

```bash
git add scenes/floors/
git commit -m "feat: add Stairs TileMapLayer to all 24 section scenes"
```

After this, the user can open any section in the Godot editor and paint stair tiles on the new Stairs layer. Since Stairs is after Walls in the scene tree, stairs will render on top of walls.
