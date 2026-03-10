#!/usr/bin/env python3
"""
shift_tiles.py — Parse narrative hub .tscn files, shift tile coordinates
so the minimum cell is at (0,0), remove the Player node, adjust non-tile
node positions, and write new section scene files.

Godot 4 tile_map_data format (PackedByteArray in .tscn):
  - 2-byte header (int16 LE, typically 0)
  - N x 12-byte records, each:
      bytes 0-1: x (int16 LE)
      bytes 2-3: y (int16 LE)
      bytes 4-5: source_id (int16 LE)
      bytes 6-7: atlas_x (int16 LE)
      bytes 8-9: atlas_y (int16 LE)
      bytes 10-11: alternative_tile (int16 LE)

Usage:
    python3 tools/shift_tiles.py

Run from the project root (service-suspended-episode-2/).
"""

import base64
import os
import re
import struct
import sys

# --- Configuration ---
TILE_SIZE = 16  # 16x16 pixel tiles

JOBS = [
    {
        "input": "scenes/train/narrative hub.tscn",
        "output": "scenes/train/sections/train_section_1.tscn",
    },
    {
        "input": "scenes/train/narrative hub 2.tscn",
        "output": "scenes/train/sections/train_section_2.tscn",
    },
]


def decode_tile_data(b64_str):
    """Decode base64 tile_map_data into header + list of cell tuples."""
    raw = base64.b64decode(b64_str)
    if len(raw) < 2:
        return 0, []
    header = struct.unpack_from("<h", raw, 0)[0]
    cells = []
    for i in range(2, len(raw), 12):
        if i + 12 > len(raw):
            break
        x, y, src, ax, ay, alt = struct.unpack_from("<hhhhhh", raw, i)
        cells.append((x, y, src, ax, ay, alt))
    return header, cells


def encode_tile_data(header, cells):
    """Encode header + cell list back to base64 string."""
    parts = [struct.pack("<h", header)]
    for x, y, src, ax, ay, alt in cells:
        parts.append(struct.pack("<hhhhhh", x, y, src, ax, ay, alt))
    raw = b"".join(parts)
    return base64.b64encode(raw).decode("ascii")


def find_all_tile_data(content):
    """Find all PackedByteArray("...") tile_map_data values in the file."""
    pattern = r'tile_map_data\s*=\s*PackedByteArray\("([A-Za-z0-9+/=]*)"\)'
    return list(re.finditer(pattern, content))


def find_global_min(content):
    """Find the global minimum x,y across all tile_map_data blobs."""
    matches = find_all_tile_data(content)
    global_min_x = 99999
    global_min_y = 99999
    for m in matches:
        b64 = m.group(1)
        if not b64:
            continue
        _header, cells = decode_tile_data(b64)
        for x, y, *_ in cells:
            global_min_x = min(global_min_x, x)
            global_min_y = min(global_min_y, y)
    if global_min_x == 99999:
        return 0, 0
    return global_min_x, global_min_y


def shift_tile_data(b64_str, dx, dy):
    """Shift all cell coordinates by (dx, dy) and return new base64."""
    header, cells = decode_tile_data(b64_str)
    shifted = [(x + dx, y + dy, src, ax, ay, alt) for x, y, src, ax, ay, alt in cells]
    return encode_tile_data(header, shifted)


def remove_player_node(content):
    """
    Remove the Player node block from the .tscn content.
    A node block starts with [node name="Player" ...] and ends at the next
    section header ([node, [sub_resource, etc.) or end of file.
    Also remove the ext_resource for player.tscn if no longer referenced.
    """
    # Line-by-line removal is more robust than regex for .tscn files
    # because node headers can contain nested brackets (e.g. groups=["Player"])
    lines = content.split("\n")
    in_player_block = False
    result_lines = []
    for line in lines:
        if re.match(r'\[node\s+name="Player"', line):
            in_player_block = True
            continue
        elif in_player_block and line.startswith("["):
            # Next section header — end of Player block
            in_player_block = False
        elif in_player_block:
            continue
        result_lines.append(line)
    content = "\n".join(result_lines)

    # Find and remove the player.tscn ext_resource line
    # First find the resource ID used for player.tscn
    player_res_pattern = r'\[ext_resource[^\]]*path="res://scenes/player/player\.tscn"[^\]]*id="([^"]+)"[^\]]*\]\n'
    player_res_match = re.search(player_res_pattern, content)
    if player_res_match:
        res_id = player_res_match.group(1)
        # Check if this resource ID is still referenced elsewhere
        # (it shouldn't be after removing the Player node)
        remaining_refs = re.findall(re.escape(f'ExtResource("{res_id}")'), content)
        if not remaining_refs:
            content = re.sub(player_res_pattern, "", content)

    return content


def shift_node_position(content, node_name, pixel_dx, pixel_dy):
    """
    Shift the position of a named node by (pixel_dx, pixel_dy) pixels.
    Only shifts nodes that are direct children of the root (parent=".").
    """
    # Match: [node name="<node_name>" ... parent="." ...]\n...position = Vector2(x, y)...
    # We need to find the node header and then its position property
    pattern = (
        r'(\[node\s+name="'
        + re.escape(node_name)
        + r'"[^\]]*parent="\."[^\]]*\]\n'
        + r'(?:(?!\[node\b)[^\n]*\n)*?)'
        + r'(position\s*=\s*Vector2\()'
        + r'([^,]+),\s*([^)]+)'
        + r'(\))'
    )
    match = re.search(pattern, content)
    if match:
        old_x = float(match.group(3))
        old_y = float(match.group(4))
        new_x = old_x + pixel_dx
        new_y = old_y + pixel_dy
        # Format to avoid unnecessary decimal places
        new_x_str = f"{new_x:g}"
        new_y_str = f"{new_y:g}"
        replacement = (
            match.group(1)
            + match.group(2)
            + new_x_str
            + ", "
            + new_y_str
            + match.group(5)
        )
        content = content[: match.start()] + replacement + content[match.end() :]
    return content


def process_scene(input_path, output_path):
    """Process one scene file: shift tiles, remove player, adjust positions."""
    print(f"\nProcessing: {input_path}")
    print(f"  Output: {output_path}")

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Find global minimum cell coordinates across all tile layers
    min_x, min_y = find_global_min(content)
    dx = -min_x  # shift to make min = 0
    dy = -min_y
    print(f"  Global min cell: ({min_x}, {min_y})")
    print(f"  Cell shift: dx={dx}, dy={dy}")
    print(f"  Pixel shift: dx={dx * TILE_SIZE}, dy={dy * TILE_SIZE}")

    # 2. Shift all tile_map_data blobs
    matches = find_all_tile_data(content)
    # Process in reverse order so indices stay valid
    for m in reversed(matches):
        old_b64 = m.group(1)
        if not old_b64:
            continue
        new_b64 = shift_tile_data(old_b64, dx, dy)
        # Replace just the base64 part inside PackedByteArray("...")
        start = m.start(1)
        end = m.end(1)
        content = content[:start] + new_b64 + content[end:]

    # 3. Remove the Player node
    content = remove_player_node(content)
    print("  Removed Player node")

    # 4. Shift the Red Coat Lady position by the same pixel offset
    pixel_dx = dx * TILE_SIZE
    pixel_dy = dy * TILE_SIZE
    content = shift_node_position(content, "Red Coat Lady", pixel_dx, pixel_dy)
    print(f"  Shifted 'Red Coat Lady' position by ({pixel_dx}, {pixel_dy}) pixels")

    # 5. Write output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  Written: {output_path}")

    # 6. Verify the result
    with open(output_path, "r", encoding="utf-8") as f:
        result = f.read()
    new_min_x, new_min_y = find_global_min(result)
    print(f"  Verification — new global min cell: ({new_min_x}, {new_min_y})")
    if "Player" in result and 'name="Player"' in result:
        print("  WARNING: Player node may still be present!")
    else:
        print("  Confirmed: Player node removed")


def main():
    # Determine project root (script should be run from service-suspended-episode-2/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)  # go up from tools/
    os.chdir(project_root)
    print(f"Working directory: {os.getcwd()}")

    for job in JOBS:
        input_path = job["input"]
        output_path = job["output"]
        if not os.path.exists(input_path):
            print(f"\nERROR: Input file not found: {input_path}")
            print(f"  Make sure you're running from the project root directory.")
            sys.exit(1)
        process_scene(input_path, output_path)

    print("\nDone! Output files:")
    for job in JOBS:
        print(f"  {job['output']}")


if __name__ == "__main__":
    main()
