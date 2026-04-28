extends Node

signal objectives_changed
signal objective_completed(id: String)

const COMPLETION_DELAY := 1.2
const MAX_DEPTH := 2

class QuestObjective:
	extends RefCounted

	var id: String = ""
	var text: String = ""
	var children: Array = []
	var completed: bool = false
	var completing: bool = false
	var progress_current: int = -1
	var progress_required: int = -1

	func _init(objective_id: String = "", objective_text: String = "", options: Dictionary = {}) -> void:
		id = objective_id
		text = objective_text
		apply_options(options)

	func apply_options(options: Dictionary) -> void:
		if options.has("progress_required"):
			progress_required = maxi(int(options["progress_required"]), 0)
		if options.has("progress_current"):
			progress_current = int(options["progress_current"])
		if has_progress():
			progress_current = clampi(progress_current if progress_current >= 0 else 0, 0, progress_required)
		else:
			progress_current = -1

	func has_progress() -> bool:
		return progress_required > 0

	func to_dict() -> Dictionary:
		var child_snapshots: Array = []
		for child in children:
			child_snapshots.append(child.to_dict())
		return {
			"id": id,
			"text": text,
			"completed": completed,
			"completing": completing,
			"progress_current": progress_current,
			"progress_required": progress_required,
			"children": child_snapshots,
		}

	static func from_dict(data: Dictionary):
		if data.is_empty():
			return null
		var options := {
			"progress_required": int(data.get("progress_required", -1)),
			"progress_current": int(data.get("progress_current", -1)),
		}
		var objective := QuestObjective.new(
			String(data.get("id", "")),
			String(data.get("text", "")),
			options
		)
		objective.completed = bool(data.get("completed", false))
		objective.completing = bool(data.get("completing", false))
		for child_data in data.get("children", []):
			if child_data is Dictionary:
				var child = QuestObjective.from_dict(child_data)
				if child != null:
					objective.children.append(child)
		return objective

var primary = null
var _pending_primary = null
var _reset_generation: int = 0

func has_primary() -> bool:
	return primary != null or _pending_primary != null

func has_objective(id: String) -> bool:
	return _find_any_objective(id).get("objective") != null

func set_primary(id: String, text: String, options: Dictionary = {}) -> void:
	if id.is_empty():
		return
	var new_primary := QuestObjective.new(id, text, options)
	if _has_completing_objectives(primary):
		_pending_primary = new_primary
		return
	primary = new_primary
	_pending_primary = null
	objectives_changed.emit()

func add_sub(id: String, text: String, parent_id: String, options: Dictionary = {}) -> void:
	if id.is_empty() or parent_id.is_empty():
		return
	var existing := _find_any_objective(id)
	var existing_objective = existing.get("objective")
	if existing_objective != null:
		existing_objective.text = text
		existing_objective.apply_options(options)
		_emit_changed_if_ready()
		return
	var parent_info := _find_any_objective(parent_id)
	var parent_objective = parent_info.get("objective")
	if parent_objective == null:
		return
	if int(parent_info.get("depth", -1)) >= MAX_DEPTH:
		return
	parent_objective.children.append(QuestObjective.new(id, text, options))
	_emit_changed_if_ready()

func update_text(id: String, text: String) -> void:
	var info := _find_any_objective(id)
	var objective = info.get("objective")
	if objective == null:
		return
	objective.text = text
	_emit_changed_if_ready()

func set_progress(id: String, current: int, required: int = -1) -> void:
	var info := _find_any_objective(id)
	var objective = info.get("objective")
	if objective == null:
		return
	if required > 0:
		objective.progress_required = required
	if not objective.has_progress():
		return
	objective.progress_current = clampi(current, 0, objective.progress_required)
	_emit_changed_if_ready()

func increment_progress(id: String, amount: int = 1) -> void:
	var info := _find_any_objective(id)
	var objective = info.get("objective")
	if objective == null or not objective.has_progress():
		return
	set_progress(id, objective.progress_current + amount)

func complete(id: String) -> void:
	var info := _find_objective_in_tree(primary, id)
	var objective = info.get("objective")
	if objective == null or objective.completed or objective.completing:
		return
	objective.completed = true
	objective.completing = true
	objective_completed.emit(id)
	var generation := _reset_generation
	await get_tree().create_timer(COMPLETION_DELAY).timeout
	if generation != _reset_generation:
		return
	if not _remove_objective_from_tree(id):
		return
	_apply_pending_primary_if_ready()
	_emit_changed_if_ready()

func remove(id: String) -> void:
	if not _remove_objective_from_tree(id):
		return
	_apply_pending_primary_if_ready()
	_emit_changed_if_ready()

func reset() -> void:
	_reset_generation += 1
	primary = null
	_pending_primary = null
	objectives_changed.emit()

func get_visible_objectives() -> Array:
	var rows: Array = []
	_append_rows(primary, 0, rows)
	return rows

func get_primary_snapshot() -> Dictionary:
	return primary.to_dict() if primary != null else {}

func get_snapshot() -> Dictionary:
	return {
		"primary": primary.to_dict() if primary != null else {},
		"pending_primary": _pending_primary.to_dict() if _pending_primary != null else {},
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	_reset_generation += 1
	primary = QuestObjective.from_dict(snapshot.get("primary", {}))
	_pending_primary = QuestObjective.from_dict(snapshot.get("pending_primary", {}))
	objectives_changed.emit()

func _append_rows(objective, depth: int, rows: Array) -> void:
	if objective == null:
		return
	rows.append({
		"id": objective.id,
		"text": objective.text,
		"depth": depth,
		"completed": objective.completed,
		"completing": objective.completing,
		"progress_current": objective.progress_current,
		"progress_required": objective.progress_required,
	})
	for child in objective.children:
		_append_rows(child, depth + 1, rows)

func _find_any_objective(id: String) -> Dictionary:
	var active_result := _find_objective_in_tree(primary, id)
	if active_result.get("objective") != null:
		return active_result
	return _find_objective_in_tree(_pending_primary, id)

func _find_objective_in_tree(objective, id: String, depth: int = 0, parent = null) -> Dictionary:
	if objective == null:
		return {"objective": null, "parent": null, "depth": -1}
	if objective.id == id:
		return {"objective": objective, "parent": parent, "depth": depth}
	for child in objective.children:
		var result := _find_objective_in_tree(child, id, depth + 1, objective)
		if result.get("objective") != null:
			return result
	return {"objective": null, "parent": null, "depth": -1}

func _remove_objective_from_tree(id: String) -> bool:
	if primary == null:
		return false
	if primary.id == id:
		primary = null
		return true
	return _remove_objective_from_children(primary, id)

func _remove_objective_from_children(parent_objective, id: String) -> bool:
	for index in range(parent_objective.children.size()):
		var child = parent_objective.children[index]
		if child.id == id:
			parent_objective.children.remove_at(index)
			return true
		if _remove_objective_from_children(child, id):
			return true
	return false

func _has_completing_objectives(objective) -> bool:
	if objective == null:
		return false
	if objective.completing:
		return true
	for child in objective.children:
		if _has_completing_objectives(child):
			return true
	return false

func _apply_pending_primary_if_ready() -> void:
	if _pending_primary == null:
		return
	if _has_completing_objectives(primary):
		return
	primary = _pending_primary
	_pending_primary = null

func _emit_changed_if_ready() -> void:
	if _has_completing_objectives(primary):
		return
	_apply_pending_primary_if_ready()
	objectives_changed.emit()
