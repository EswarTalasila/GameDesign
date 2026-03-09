# Health Pickup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a health pickup item that restores 1 HP when walked over (skipped at full health), using the same marker-based tile entity system as ticket and key pickups.

**Architecture:** Export the Health_pickup_item.aseprite as a spritesheet, create a spawn marker PNG for the tileset, register it as source 2 in item_spawn_markers.tres, build a health_pickup scene/script following the ticket/key pattern, and wire it into tile_entities.gd.

**Tech Stack:** Godot 4.6, Aseprite CLI, GDScript

---

### Task 1: Export Aseprite spritesheet

**Files:**
- Source: `../../assets/UI/UI Components/Health_pickup_item.aseprite`
- Create: `assets/sprites/pickups/health/health_pickup_float.png`

**Step 1: Create output directory**

```bash
mkdir -p service-suspended-episode-2/assets/sprites/pickups/health
```

**Step 2: Export the spritesheet as a horizontal strip**

```bash
/Applications/Aseprite.app/Contents/MacOS/aseprite -b \
  "assets/UI/UI Components/Health_pickup_item.aseprite" \
  --sheet-type horizontal \
  --sheet "service-suspended-episode-2/assets/sprites/pickups/health/health_pickup_float.png"
```

Expected: 96x32 PNG (6 frames × 16x32 each).

**Step 3: Verify output**

```bash
file service-suspended-episode-2/assets/sprites/pickups/health/health_pickup_float.png
```

Expected: `PNG image data, 96 x 32, 8-bit/color RGBA`

---

### Task 2: Create spawn marker for tileset

**Files:**
- Create: `assets/sprites/pickups/health/health_spawn_marker.png`

**Step 1: Extract frame 0 as the spawn marker**

```bash
/Applications/Aseprite.app/Contents/MacOS/aseprite -b \
  "assets/UI/UI Components/Health_pickup_item.aseprite" \
  --frame-range 0,0 \
  --save-as "service-suspended-episode-2/assets/sprites/pickups/health/health_spawn_marker.png"
```

Expected: 16x32 single-frame PNG.

**Step 2: Verify dimensions match ticket spawn marker (16x32)**

```bash
file service-suspended-episode-2/assets/sprites/pickups/health/health_spawn_marker.png
```

Expected: `PNG image data, 16 x 32, 8-bit/color RGBA`

---

### Task 3: Add source 2 to item_spawn_markers.tres

**Files:**
- Modify: `assets/tilesets/dungeon/item_spawn_markers.tres`

Currently has source 0 (ticket, 16x32) and source 1 (key, 16x48). Add source 2 for health (16x32).

**Step 1: Add the ext_resource and TileSetAtlasSource**

Add after the key ext_resource line:
```
[ext_resource type="Texture2D" path="res://assets/sprites/pickups/health/health_spawn_marker.png" id="3_health"]
```

Add after SubResource("2"):
```
[sub_resource type="TileSetAtlasSource" id="3"]
texture = ExtResource("3_health")
texture_region_size = Vector2i(16, 32)
0:0/0 = 0
```

Update load_steps from current value to +2 (for the new ext_resource + sub_resource).

Add to the resource section:
```
sources/2 = SubResource("3")
```

**Step 2: Open Godot and verify source 2 appears in the item_spawn_markers tileset**

---

### Task 4: Create health_pickup.gd script

**Files:**
- Create: `scenes/pickups/health_pickup.gd`

**Full code:**
```gdscript
extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	collision_layer = 4   # layer 3
	collision_mask = 1    # detect player (layer 1)
	body_entered.connect(_on_body_entered)
	_start_glow_pulse()

func _start_glow_pulse() -> void:
	var mat = sprite.material as ShaderMaterial
	if not mat or not mat.get_shader_parameter("glow_enabled"):
		return
	var tween = create_tween().set_loops()
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.7, 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(_body: Node2D) -> void:
	if GameState.player_health >= GameState.max_health:
		return
	set_deferred("monitoring", false)
	GameState.heal_player(1)

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
```

Key difference from ticket/key: the `if GameState.player_health >= GameState.max_health: return` guard at the top of `_on_body_entered`. Player walks through it when at full health.

---

### Task 5: Create health_pickup.tscn scene

**Files:**
- Create: `scenes/pickups/health_pickup.tscn`

This follows the exact same structure as ticket_pickup.tscn:
- Root: Area2D ("HealthPickup"), collision_layer=4, collision_mask=1, script=health_pickup.gd
- Child: AnimatedSprite2D with outline glow shader material, position=(0,-8), SpriteFrames with 6-frame "float" animation at 10fps using 16x32 AtlasTextures from health_pickup_float.png
- Child: CollisionShape2D with RectangleShape2D size=(12,12)

The .tscn file is long (AtlasTexture sub-resources for 6 frames). Build it by copying ticket_pickup.tscn structure and adjusting:
- Root node name: HealthPickup
- Script path: `res://scenes/pickups/health_pickup.gd`
- Texture path: `res://assets/sprites/pickups/health/health_pickup_float.png`
- 6 frames instead of 12 (frame regions: 0,0→16,32 through 80,0→16,32)
- load_steps adjusted accordingly

---

### Task 6: Register in tile_entities.gd

**Files:**
- Modify: `scenes/floors/shared/tile_entities.gd`

**Step 1: Add entry after the key pickup line (line 34)**

```gdscript
# Health pickups (scanned from Items layer — source 2 in item_spawn_markers.tres)
{ "source": 2, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/health_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" },
```

---

### Task 7: Verify in-game

**Step 1:** Open a section scene in the Godot editor and paint a health pickup marker (source 2, tile 0,0) in the Items layer.

**Step 2:** Run the scene. Walk over the health pickup:
- At full health → pickup stays, player walks through it
- After taking damage → pickup consumed, heals 1 HP, glow pulse + tween out animation
- Health bar updates correctly

**Step 3: Commit**

```bash
git add scenes/pickups/health_pickup.gd scenes/pickups/health_pickup.tscn \
  assets/sprites/pickups/health/ assets/tilesets/dungeon/item_spawn_markers.tres \
  scenes/floors/shared/tile_entities.gd
git commit -m "feat: add health pickup item (1HP heal, skipped at full health)"
```
