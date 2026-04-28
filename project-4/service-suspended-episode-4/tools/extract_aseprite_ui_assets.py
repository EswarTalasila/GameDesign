#!/usr/bin/env python3
from __future__ import annotations

import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MAP_SOURCE = ROOT / "assets" / "Map+paths.aseprite"
CLOCK_SOURCE = ROOT / "assets" / "Clock_Assets.aseprite"
STONE_PUZZLE_SOURCE = ROOT / "assets" / "Stone Puzzle.aseprite"
BOSS_EAST_SOURCE = ROOT / "assets" / "Boss_64x64_animations_east.aseprite"
BOSS_WEST_SOURCE = ROOT / "assets" / "Boss_64x64_animations_west.aseprite"
MAP_OUTPUT = ROOT / "service-suspended-episode-4" / "assets" / "ui" / "map"
CLOCK_OUTPUT = ROOT / "service-suspended-episode-4" / "assets" / "ui" / "clock"
STONE_PUZZLE_OUTPUT = ROOT / "service-suspended-episode-4" / "assets" / "sprites" / "stone_puzzle"
BOSS_OUTPUT = ROOT / "service-suspended-episode-4" / "assets" / "sprites" / "enemies" / "boss"

COLOR_LAYERS = {
    "red": "Red",
    "yellow": "Yellow",
    "blue": "Blue",
    "green": "Green",
    "purple": "Purple",
    "white": "White",
}

STONE_SINGLE_TAGS = {
    "altar": "Stone Alter",
    "board": "UI",
    "black": "Black Stone",
    "blue": "Blue Stone",
    "green": "Green Stone",
    "purple": "Purple Stone",
    "red": "Red Stone",
    "white": "White Stone",
    "yellow": "Yellow Stone",
}

STONE_PICKUP_TAGS = {
    "black": "Black Stone Pickup",
    "blue": "Blue Stone Pickup",
    "green": "Green Stone Pickup",
    "purple": "Purple Stone Pickup",
    "red": "Red Stone Pickup",
    "white": "White Stone Pickup",
    "yellow": "Yellow Stone Pickup",
}

BOSS_TAGS = ["walk", "attack", "hit", "death", "spawn"]
BOSS_ANIMATION_SPEEDS = {
    "attack_east": 10.0,
    "attack_west": 10.0,
    "death_east": 10.0,
    "death_west": 10.0,
    "dormant": 1.0,
    "hit_east": 10.0,
    "hit_west": 10.0,
    "idle_east": 5.0,
    "idle_west": 5.0,
    "spawn_east": 10.0,
    "spawn_west": 10.0,
    "walk_east": 10.0,
    "walk_west": 10.0,
}
BOSS_LOOPING_ANIMATIONS = {"dormant", "idle_east", "idle_west", "walk_east", "walk_west"}


@dataclass
class LayerInfo:
    name: str
    flags: int
    layer_type: int
    opacity: int


@dataclass
class CelInfo:
    x: int
    y: int
    opacity: int
    cel_type: int
    width: int = 0
    height: int = 0
    raw: bytes | None = None
    linked_frame: int = -1


class AsepriteFile:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data = path.read_bytes()
        self.width = 0
        self.height = 0
        self.frames: list[dict[int, CelInfo]] = []
        self.layers: list[LayerInfo] = []
        self.tags: dict[str, tuple[int, int]] = {}
        self._parse()

    def _parse(self) -> None:
        file_size, magic, frame_count, width, height, depth = struct.unpack_from(
            "<IHHHHH", self.data, 0
        )
        if magic != 0xA5E0:
            raise ValueError(f"{self.path} is not an Aseprite file")
        if depth != 32:
            raise ValueError(f"{self.path} uses unsupported color depth {depth}")
        if file_size != len(self.data):
            raise ValueError(f"{self.path} size header does not match file size")

        self.width = width
        self.height = height

        offset = 128
        for _frame_index in range(frame_count):
            frame_size, frame_magic, old_chunk_count, _duration = struct.unpack_from(
                "<IHHH", self.data, offset
            )
            if frame_magic != 0xF1FA:
                raise ValueError(f"{self.path} has an invalid frame header")
            chunk_count = struct.unpack_from("<I", self.data, offset + 12)[0] or old_chunk_count
            frame_cels: dict[int, CelInfo] = {}
            chunk_offset = offset + 16
            for _chunk_index in range(chunk_count):
                chunk_size, chunk_type = struct.unpack_from("<IH", self.data, chunk_offset)
                if chunk_type == 0x2004:
                    self.layers.append(self._parse_layer(chunk_offset))
                elif chunk_type == 0x2005:
                    layer_index, cel = self._parse_cel(chunk_offset)
                    frame_cels[layer_index] = cel
                elif chunk_type == 0x2018:
                    self.tags.update(self._parse_tags(chunk_offset))
                chunk_offset += chunk_size
            self.frames.append(frame_cels)
            offset += frame_size

    def _parse_layer(self, chunk_offset: int) -> LayerInfo:
        flags, layer_type, _child_level, _default_width, _default_height, _blend_mode, opacity = (
            struct.unpack_from("<HHHHHHB", self.data, chunk_offset + 6)
        )
        name_length = struct.unpack_from("<H", self.data, chunk_offset + 22)[0]
        name = self.data[chunk_offset + 24 : chunk_offset + 24 + name_length].decode(
            "utf-8", "replace"
        )
        return LayerInfo(name=name, flags=flags, layer_type=layer_type, opacity=opacity)

    def _parse_cel(self, chunk_offset: int) -> tuple[int, CelInfo]:
        layer_index, x, y, opacity, cel_type, _z_index = struct.unpack_from(
            "<HhhBHH", self.data, chunk_offset + 6
        )
        payload_offset = chunk_offset + 22
        if cel_type == 1:
            linked_frame = struct.unpack_from("<H", self.data, payload_offset)[0]
            return layer_index, CelInfo(x=x, y=y, opacity=opacity, cel_type=cel_type, linked_frame=linked_frame)

        width, height = struct.unpack_from("<HH", self.data, payload_offset)
        raw_data = self.data[payload_offset + 4 : chunk_offset + struct.unpack_from("<I", self.data, chunk_offset)[0]]
        if cel_type == 2:
            raw_data = zlib.decompress(raw_data)
        elif cel_type != 0:
            raise ValueError(f"{self.path} uses unsupported cel type {cel_type}")

        return layer_index, CelInfo(
            x=x,
            y=y,
            opacity=opacity,
            cel_type=cel_type,
            width=width,
            height=height,
            raw=raw_data,
        )

    def _parse_tags(self, chunk_offset: int) -> dict[str, tuple[int, int]]:
        tag_count = struct.unpack_from("<H", self.data, chunk_offset + 6)[0]
        tags: dict[str, tuple[int, int]] = {}
        tag_offset = chunk_offset + 16
        for _ in range(tag_count):
            start_frame, end_frame, _loop_direction, _repeat = struct.unpack_from(
                "<HHBH", self.data, tag_offset
            )
            name_length = struct.unpack_from("<H", self.data, tag_offset + 17)[0]
            name = self.data[tag_offset + 19 : tag_offset + 19 + name_length].decode(
                "utf-8", "replace"
            )
            tags[name] = (start_frame, end_frame)
            tag_offset += 19 + name_length
        return tags

    def _resolve_cel(self, frame_index: int, layer_index: int) -> CelInfo | None:
        cel = self.frames[frame_index].get(layer_index)
        if cel is None:
            return None
        if cel.cel_type == 1:
            return self._resolve_cel(cel.linked_frame, layer_index)
        return cel

    def render(self, frame_index: int, layer_names: list[str] | None = None) -> Image.Image:
        allowed = None if layer_names is None else set(layer_names)
        image = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
        for layer_index, layer in enumerate(self.layers):
            if layer.layer_type != 0:
                continue
            if not (layer.flags & 1):
                continue
            if allowed is not None and layer.name not in allowed:
                continue
            cel = self._resolve_cel(frame_index, layer_index)
            if cel is None or cel.raw is None:
                continue
            cel_image = Image.frombytes("RGBA", (cel.width, cel.height), cel.raw)
            effective_opacity = cel.opacity * layer.opacity // 255
            if effective_opacity < 255:
                r, g, b, a = cel_image.split()
                a = a.point(lambda value, op=effective_opacity: value * op // 255)
                cel_image = Image.merge("RGBA", (r, g, b, a))
            cel_canvas = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
            cel_canvas.alpha_composite(cel_image, (cel.x, cel.y))
            image = Image.alpha_composite(image, cel_canvas)
        return image

    def tag_frame(self, tag_name: str) -> int:
        start_frame, _end_frame = self.tags[tag_name]
        return start_frame

    def tag_range(self, tag_name: str) -> range:
        start_frame, end_frame = self.tags[tag_name]
        return range(start_frame, end_frame + 1)


def _save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def _crop(image: Image.Image, bounds: tuple[int, int, int, int] | None = None) -> Image.Image:
    crop_bounds = bounds if bounds is not None else image.getbbox()
    if crop_bounds is None:
        return image.copy()
    return image.crop(crop_bounds)


def _union_bounds(bounds: list[tuple[int, int, int, int] | None]) -> tuple[int, int, int, int] | None:
    valid_bounds = [bound for bound in bounds if bound is not None]
    if not valid_bounds:
        return None
    return (
        min(bound[0] for bound in valid_bounds),
        min(bound[1] for bound in valid_bounds),
        max(bound[2] for bound in valid_bounds),
        max(bound[3] for bound in valid_bounds),
    )


def export_map_assets() -> None:
    ase = AsepriteFile(MAP_SOURCE)

    _save(ase.render(ase.tag_frame("Taped Map UI"), ["Layer 1"]), MAP_OUTPUT / "taped_map_ui.png")
    _save(ase.render(ase.tag_frame("Map Inventory Icon"), ["Layer 1"]), MAP_OUTPUT / "icon.png")

    for frame_number, frame_index in enumerate(ase.tag_range("Map Piece pickup"), start=1):
        _save(ase.render(frame_index, ["Layer 1"]), MAP_OUTPUT / f"pickup_{frame_number}.png")

    trees_output = MAP_OUTPUT / "trees"
    for position in range(1, 7):
        frame_index = ase.tag_frame(f"position {position}")
        for color_name, layer_name in COLOR_LAYERS.items():
            # Render ONLY the color layer — transparent overlay so all 6 trees
            # are visible simultaneously on top of the base map sprite.
            image = ase.render(frame_index, [layer_name])
            _save(image, trees_output / f"position_{position}_{color_name}.png")


def export_clock_assets() -> None:
    ase = AsepriteFile(CLOCK_SOURCE)
    for frame_number, frame_index in enumerate(ase.tag_range("Map Clock"), start=1):
        _save(ase.render(frame_index), CLOCK_OUTPUT / f"map_clock_{frame_number}.png")


def export_stone_puzzle_assets() -> None:
    ase = AsepriteFile(STONE_PUZZLE_SOURCE)

    _save(
        _crop(ase.render(ase.tag_frame(STONE_SINGLE_TAGS["altar"]))),
        STONE_PUZZLE_OUTPUT / "altar" / "stone_altar.png",
    )
    _save(
        _crop(ase.render(ase.tag_frame(STONE_SINGLE_TAGS["board"]))),
        STONE_PUZZLE_OUTPUT / "ui" / "stone_puzzle_board.png",
    )

    for color_name in ["black", "blue", "green", "purple", "red", "white", "yellow"]:
        _save(
            _crop(ase.render(ase.tag_frame(STONE_SINGLE_TAGS[color_name]))),
            STONE_PUZZLE_OUTPUT / "stones" / f"{color_name}_stone.png",
        )

    for color_name, tag_name in STONE_PICKUP_TAGS.items():
        frame_indexes = list(ase.tag_range(tag_name))
        bounds = _union_bounds([ase.render(frame_index).getbbox() for frame_index in frame_indexes])
        for frame_number, frame_index in enumerate(frame_indexes, start=1):
            _save(
                _crop(ase.render(frame_index), bounds),
                STONE_PUZZLE_OUTPUT / "pickups" / f"{color_name}_stone_pickup_{frame_number}.png",
            )


def export_boss_assets() -> None:
    for direction, source in [("east", BOSS_EAST_SOURCE), ("west", BOSS_WEST_SOURCE)]:
        ase = AsepriteFile(source)
        walk_frames = list(ase.tag_range("walk"))
        walk_bounds = _union_bounds([ase.render(frame_index).getbbox() for frame_index in walk_frames])
        if direction == "east":
            _save(
                _crop(ase.render(walk_frames[0]), walk_bounds),
                BOSS_OUTPUT / "dormant_frame_east.png",
            )
        for tag_name in BOSS_TAGS:
            frame_indexes = list(ase.tag_range(tag_name))
            bounds = _union_bounds([ase.render(frame_index).getbbox() for frame_index in frame_indexes])
            for frame_number, frame_index in enumerate(frame_indexes):
                _save(
                    _crop(ase.render(frame_index), bounds),
                    BOSS_OUTPUT / f"{tag_name}_{direction}" / f"frame_{frame_number:03d}.png",
                )
    _write_boss_frames_resource()


def _write_boss_frames_resource() -> None:
    resources: list[tuple[str, str]] = []
    animations: list[tuple[str, list[int], bool, float]] = []

    def add_texture(path: Path) -> int:
        resources.append(("Texture2D", f"res://{path.relative_to(ROOT / 'service-suspended-episode-4').as_posix()}"))
        return len(resources)

    def add_animation(name: str, paths: list[Path], loop: bool, speed: float) -> None:
        ids = [add_texture(path) for path in paths]
        animations.append((name, ids, loop, speed))

    dormant_id = add_texture(BOSS_OUTPUT / "dormant_frame_east.png")

    for name in ["attack_east", "attack_west", "death_east", "death_west"]:
        tag_name, direction = name.split("_", 1)
        frame_paths = sorted((BOSS_OUTPUT / f"{tag_name}_{direction}").glob("frame_*.png"))
        add_animation(name, frame_paths, name in BOSS_LOOPING_ANIMATIONS, BOSS_ANIMATION_SPEEDS[name])

    animations.append(("dormant", [dormant_id], True, BOSS_ANIMATION_SPEEDS["dormant"]))

    idle_east_first = BOSS_OUTPUT / "walk_east" / "frame_000.png"
    idle_west_first = BOSS_OUTPUT / "walk_west" / "frame_000.png"
    add_animation("hit_east", sorted((BOSS_OUTPUT / "hit_east").glob("frame_*.png")), False, BOSS_ANIMATION_SPEEDS["hit_east"])
    add_animation("hit_west", sorted((BOSS_OUTPUT / "hit_west").glob("frame_*.png")), False, BOSS_ANIMATION_SPEEDS["hit_west"])
    add_animation("idle_east", [idle_east_first], True, BOSS_ANIMATION_SPEEDS["idle_east"])
    add_animation("idle_west", [idle_west_first], True, BOSS_ANIMATION_SPEEDS["idle_west"])
    add_animation("spawn_east", sorted((BOSS_OUTPUT / "spawn_east").glob("frame_*.png")), False, BOSS_ANIMATION_SPEEDS["spawn_east"])
    add_animation("spawn_west", sorted((BOSS_OUTPUT / "spawn_west").glob("frame_*.png")), False, BOSS_ANIMATION_SPEEDS["spawn_west"])
    add_animation("walk_east", sorted((BOSS_OUTPUT / "walk_east").glob("frame_*.png")), True, BOSS_ANIMATION_SPEEDS["walk_east"])
    add_animation("walk_west", sorted((BOSS_OUTPUT / "walk_west").glob("frame_*.png")), True, BOSS_ANIMATION_SPEEDS["walk_west"])

    lines = ['[gd_resource type="SpriteFrames" format=3]']
    for index, (resource_type, path) in enumerate(resources, start=1):
        lines.append(f'[ext_resource type="{resource_type}" path="{path}" id="{index}"]')
    lines.append("")
    lines.append("[resource]")
    lines.append("animations = [")
    for animation_index, (name, ids, loop, speed) in enumerate(animations):
        frame_blob = ", ".join(
            f'{{"duration": 1.0, "texture": ExtResource("{resource_id}")}}'
            for resource_id in ids
        )
        lines.append("{")
        lines.append(f'"frames": [{frame_blob}],')
        lines.append(f'"loop": {"true" if loop else "false"},')
        lines.append(f'"name": &"{name}",')
        lines.append(f'"speed": {speed}')
        lines.append("}" + ("," if animation_index < len(animations) - 1 else ""))
    lines.append("]")
    (BOSS_OUTPUT / "boss_frames.tres").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {(BOSS_OUTPUT / 'boss_frames.tres').relative_to(ROOT)}")


def main() -> None:
    export_map_assets()
    export_clock_assets()
    export_stone_puzzle_assets()
    export_boss_assets()


if __name__ == "__main__":
    main()
