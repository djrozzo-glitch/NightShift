extends Node3D
const UIStyle = preload("res://scripts/ui_style.gd")
## First migration milestone: a playable 3D camera and procedural club shell.
## Controls: left-drag rotate, shift+left-drag pan, wheel zoom, R reset.

const SIZE := 16
const TILE := 1.0
const MIN_ZOOM := 5.0
const MAX_ZOOM := 27.0

var camera: Camera3D
var pivot: Node3D
var zoom := 16.0
var yaw := deg_to_rad(45.0)
var tilt := deg_to_rad(-55.0)
var dragging := false
var last_mouse := Vector2.ZERO
var build_mode := false
var occupied: Dictionary = {}
var floor_heights: Dictionary = {}
var hover_cell := Vector2i(-1, -1)
var hover_mesh: MeshInstance3D
var status_label: Label
const BUILD_TYPES := ["speaker", "dj", "bar", "sofa", "wc", "table", "stool", "plant2", "light", "laser"]
var selected_kind := "speaker"
var build_turn := 0
var preview_root: Node3D
var build_panel: PanelContainer
var build_toggle: Button
var help_label: Label
var erase_mode := false
var placed_objects: Dictionary = {}
var object_at_cell: Dictionary = {}
var next_object_id := 1
var action_history: Array[Dictionary] = []
# Prototype economy: prices and starting balance will be balanced later.
const BUILD_PRICES := {"speaker": 300, "dj": 1200, "bar": 850, "sofa": 400, "wc": 650, "table": 100, "stool": 75, "plant2": 90, "light": 250, "laser": 450}
var cash := 15000
var reputation := 100
var club_level := 1
var economy_label: Label
var notice_label: Label
var readiness_label: Label
var dj_picker: OptionButton
var start_night_button: Button
var night_active := false
var night_number := 0
var guest_layer: Node3D
var guests: Array[Dictionary] = []
var guest_spawn_clock := 0.0
var guest_count := 0
const NIGHT_DURATION := 180.0
const TICKET_PRICE := 20
const DRINK_PRICE := 8
const STAFF_COST := 120
var night_elapsed := 0.0
var night_speed := 1.0
var night_paused := false
var night_ticket_income := 0
var night_drink_income := 0
var night_dj_fee := 0
var night_drinks_sold := 0
var night_time_label: Label
var night_speed_button: Button
var night_pause_button: Button
var night_report_panel: PanelContainer
var night_report_heading: Label
var night_report_details: Label
const MAX_GUESTS := 28
const GUEST_CHARACTER_NAMES := ["baggy_m", "fashion_f", "jungle_f", "raver_f", "raver_m"]
var guest_models: Dictionary = {}

const GUEST_ENTRY := Vector2i(7, 14)
const WALK_DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const DJ_ROSTER := [
	{"name": "Vanya Velin", "fee": 400},
	{"name": "Velvet 37", "fee": 300},
	{"name": "rozzo", "fee": 350},
	{"name": "lowQ", "fee": 250}
]

func _ready() -> void:
	_build_world()
	_load_guest_models()
	guest_layer = Node3D.new()
	guest_layer.name = "Guests"
	add_child(guest_layer)
	_build_camera()
	_build_overlay()
	_build_hover()

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)
	return item

const MODEL_TYPES := ["wall", "poster", "dj", "bar", "sofa", "speaker", "light", "laser", "plant2", "table", "stool", "wc", "entrance", "floor"]
var models: Dictionary = {}
var club: Node3D
var missing_models: Array[String] = []
var club_environment: Environment
var club_sun: DirectionalLight3D
var stage_lights: Array[SpotLight3D] = []
var lighting_clock := 0.0
var dance_lights: Array[OmniLight3D] = []
var beam_meshes: Array[MeshInstance3D] = []
var disco_spots: Array[SpotLight3D] = []
const DISCO_COLORS := [Color("#a75bff"), Color("#40c9ff"), Color("#ff4bba"), Color("#ffbc55"), Color("#f3f7ff")]
var laser_spots: Array[SpotLight3D] = []
var laser_beams: Array[MeshInstance3D] = []
const LASER_COLORS := [Color("#31ff64"), Color("#287cff"), Color("#ffffff"), Color("#ff334d")]

func _load_models() -> void:
	for kind in MODEL_TYPES:
		var path := "res://assets/models/%s.glb" % kind
		if ResourceLoader.exists(path):
			var packed := load(path) as PackedScene
			if packed != null:
				models[kind] = packed
			else:
				missing_models.append(kind)
				push_warning("NightShift: cannot import %s" % path)
		else:
			missing_models.append(kind)
			push_warning("NightShift: missing %s" % path)

const TWO_CELL := ["dj", "bar", "sofa", "wc", "entrance"]

func _model(parent: Node3D, kind: String, x: int, y: int, turn: int = 0) -> Node3D:
	# Separate the grid pivot from the visible GLB so 90-degree turns rotate
	# around the occupied footprint rather than the GLB author's origin.
	var pivot_node := Node3D.new()
	pivot_node.name = "%s_%d_%d" % [kind, x, y]
	parent.add_child(pivot_node)
	pivot_node.position = Vector3(x - 7.5, 0, y - 7.5)
	# Perimeter meshes sit at the INNER edge of the perimeter tiles.
	if kind in ["wall", "poster"]:
		if x == 0:
			pivot_node.position.x += 0.48
		elif x == SIZE - 1:
			pivot_node.position.x -= 0.48
		if y == 0:
			pivot_node.position.z += 0.48
		elif y == SIZE - 1:
			pivot_node.position.z -= 0.48
	elif kind == "entrance":
		# Entrance is two cells wide, centered on the gap at x=7..8.
		pivot_node.position.x += 0.5
		pivot_node.position.z -= 0.48
	pivot_node.rotation.y = float(turn) * PI * 0.5
	if kind == "entrance":
		pivot_node.rotation.y += PI
	if kind == "poster":
		# Face the artwork into the room on each perimeter side.
		if x == 0:
			pivot_node.rotation.y = PI * 0.5
		elif x == SIZE - 1:
			pivot_node.rotation.y = -PI * 0.5
		elif y == 0:
			pivot_node.rotation.y = PI
	if not models.has(kind):
		var color: Color = Color("#5d456a") if kind in TWO_CELL else Color("#53505b")
		_make_box(pivot_node, Vector3(0, 0.4, 0.5 if kind in TWO_CELL else 0.0),
			Vector3(0.8, 0.8, 1.8 if kind in TWO_CELL else 0.8), color)
		return pivot_node

	var visual := (models[kind] as PackedScene).instantiate() as Node3D
	pivot_node.add_child(visual)
	var bounds := _visual_bounds(visual)
	var native_width := minf(bounds.size.x, bounds.size.z)
	var native_length := maxf(bounds.size.x, bounds.size.z)
	if bounds.size.length_squared() < 0.000001:
		push_warning("NightShift: empty model %s" % kind)
		return pivot_node

	# All two-cell objects occupy the local +Z direction before grid rotation.
	if kind in TWO_CELL and bounds.size.x > bounds.size.z:
		# Orient the authored long side along local Z before grid rotation.
		visual.rotation.y = PI * 0.5
		bounds = _visual_bounds(pivot_node)

	var target_x := 0.9
	var target_z := 0.9
	if kind in TWO_CELL:
		target_x = 0.94
		target_z = 1.88
	elif kind == "stool" or kind == "table":
		target_x = 0.53
		target_z = 0.53
	elif kind == "light" or kind == "laser":
		target_x = 0.60
		target_z = 0.60
	elif kind == "plant2":
		target_x = 0.78
		target_z = 0.78
	elif kind == "floor":
		target_x = 0.99
		target_z = 0.99
	elif kind == "poster":
		target_x = 0.88
		target_z = 0.88

	# Use the model's native aspect ratio. Two-cell assets are sized by
	# their LONG side; never independently stretch their X and Z axes.
	var fit_scale: float
	if kind == "entrance":
		fit_scale = 1.90 / maxf(native_length, 0.001)
	elif kind in TWO_CELL:
		fit_scale = minf(target_z / maxf(native_length, 0.001),
			target_x / maxf(native_width, 0.001))
		# Measure the original GLB before rotating it: imported node transforms
		# can make rotated AABBs report the wrong length during this frame.
	else:
		fit_scale = minf(target_x / maxf(bounds.size.x, 0.001),
			target_z / maxf(bounds.size.z, 0.001))
	# Do not shrink large furniture merely because its authored height is tall.
	if kind == "stool" or kind == "table":
		fit_scale = minf(fit_scale, 0.65 / maxf(bounds.size.y, 0.001))
	elif kind == "floor":
		fit_scale = minf(fit_scale, 0.22 / maxf(bounds.size.y, 0.001))
	visual.scale = Vector3.ONE * fit_scale
	bounds = _visual_bounds(pivot_node)
	# Bottom of the geometry rests on top of the base floor, not inside it.
	# The footprint center is half a cell forward for two-cell objects.
	var offset_z := 0.5 if kind in TWO_CELL and kind != "entrance" else 0.0
	var base_y := 0.0 if kind == "floor" else float(floor_heights.get(Vector2i(x, y), -0.005)) + 0.012
	visual.position += Vector3(-bounds.get_center().x,
		base_y - bounds.position.y,
		offset_z - bounds.get_center().z)
	if kind == "floor":
		floor_heights[Vector2i(x, y)] = _visual_bounds(pivot_node).end.y
	return pivot_node

func _visual_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		var aabb := local * mesh.get_aabb()
		if not found:
			bounds = aabb
			found = true
		else:
			bounds = bounds.merge(aabb)
	return bounds

func _register_object(node: Node3D, kind: String, x: int, y: int, turn: int) -> int:
	var id := next_object_id
	next_object_id += 1
	var cells := _footprint(x, y, kind, turn)
	placed_objects[id] = {"node": node, "kind": kind, "x": x, "y": y, "turn": turn, "cells": cells}
	for cell in cells:
		occupied[cell] = true
		object_at_cell[cell] = id
	return id

func _refresh_economy() -> void:
	_refresh_readiness()
	if economy_label != null:
		economy_label.text = "CASH  €%d     REP  %d/100     LEVEL  %d" % [cash, reputation, club_level]

func _count_kind(kind: String) -> int:
	var count := 0
	for record in placed_objects.values():
		if record["kind"] == kind:
			count += 1
	return count

func _readiness_issues() -> Array[String]:
	var issues: Array[String] = []
	if _count_kind("dj") < 1:
		issues.append("DJ booth")
	if _count_kind("speaker") < 2:
		issues.append("2 speakers")
	if _count_kind("bar") < 1:
		issues.append("bar")
	if _count_kind("wc") < 1:
		issues.append("restroom")
	if dj_picker != null and dj_picker.selected >= 0:
		var fee := int(DJ_ROSTER[dj_picker.selected]["fee"])
		if cash < fee:
			issues.append("€%d DJ fee" % fee)
	return issues

func _refresh_readiness() -> void:
	if readiness_label == null:
		return
	var issues := _readiness_issues()
	if night_active:
		readiness_label.text = "NIGHT %d  |  %d GUESTS" % [night_number, guest_count]
	elif issues.is_empty():
		readiness_label.text = "READY TO OPEN  ✓"
	else:
		readiness_label.text = "NEEDS: " + ", ".join(issues)
	if start_night_button != null:
		start_night_button.disabled = not night_active and not issues.is_empty()

func _walkable(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.x < SIZE - 1 and cell.y > 0 and cell.y < SIZE - 1 and not occupied.has(cell)

func _path_to(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _walkable(start) or not _walkable(goal):
		return result
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if current == goal:
			break
		for direction in WALK_DIRS:
			var neighbor: Vector2i = current + direction
			if _walkable(neighbor) and not previous.has(neighbor):
				previous[neighbor] = current
				queue.append(neighbor)
	if not previous.has(goal):
		return result
	var cell := goal
	while cell != start:
		result.push_front(cell)
		cell = previous[cell]
	return result

func _path_around_guests(start: Vector2i, goal: Vector2i, self_guest: Dictionary) -> Array[Vector2i]:
	var blocked: Dictionary = {}
	for other in guests:
		if other == self_guest or bool(other.get("seated", false)):
			continue
		var other_node: Node3D = other["node"]
		if not is_instance_valid(other_node):
			continue
		var location := Vector2i(roundi(other_node.position.x + 7.5), roundi(other_node.position.z + 7.5))
		if location != start and location != goal:
			blocked[location] = true
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		if current == goal:
			break
		for direction in WALK_DIRS:
			var neighbor: Vector2i = current + direction
			if _walkable(neighbor) and not blocked.has(neighbor) and not previous.has(neighbor):
				previous[neighbor] = current
				queue.append(neighbor)
	var result: Array[Vector2i] = []
	if not previous.has(goal):
		return result
	var cell := goal
	while cell != start:
		result.push_front(cell)
		cell = previous[cell]
	return result

func _cell_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - 7.5, float(floor_heights.get(cell, 0.0)) + 0.05, cell.y - 7.5)

func _destination_taken(cell: Vector2i, except_guest: Dictionary = {}) -> bool:
	for other in guests:
		if other == except_guest:
			continue
		if other.get("destination", Vector2i(-1, -1)) == cell:
			return true
	return false

func _guest_too_close(check_position: Vector3, except_guest: Dictionary, minimum_distance: float = 0.46) -> bool:
	for other in guests:
		if other == except_guest or bool(other.get("seated", false)):
			continue
		var other_node: Node3D = other["node"]
		if is_instance_valid(other_node) and other_node.position.distance_squared_to(check_position) < minimum_distance * minimum_distance:
			return true
	return false

func _dance_destination() -> Vector2i:
	for attempt in range(35):
		var candidate := Vector2i(randi_range(3, 12), randi_range(3, 9))
		if _walkable(candidate) and not _destination_taken(candidate) and not _path_to(GUEST_ENTRY, candidate).is_empty():
			return candidate
	return Vector2i(-1, -1)

func _load_guest_models() -> void:
	guest_models.clear()
	for character_name in GUEST_CHARACTER_NAMES:
		var variants: Dictionary = {}
		for motion in ["idle", "walk", "dance", "sit", "drink", "chat"]:
			var path := "res://characters/%s_%s.glb" % [character_name, motion]
			if character_name == "raver_m" and motion == "sit":
				path = "res://characters/raver_m_sit 2.glb"
			if ResourceLoader.exists(path):
				var packed := load(path) as PackedScene
				if packed != null:
					variants[motion] = packed
		if variants.has("walk") and variants.has("dance"):
			guest_models[character_name] = variants

func _guest_animated_model(packed: PackedScene, parent: Node3D) -> Node3D:
	var imported := packed.instantiate() as Node3D
	if imported == null:
		return null
	parent.add_child(imported)
	# Skinned GLB meshes can report unreliable rest-pose AABBs. Never amplify
	# tiny bounds into giant characters; keep imported geometry within a tile.
	var bounds := _visual_bounds(imported)
	if bounds.size.y > 0.01:
		var longest_axis := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z))
		var factor := clampf(0.56 / longest_axis, 0.01, 1.0)
		imported.scale = Vector3.ONE * factor
		bounds = _visual_bounds(imported)
		if absf(bounds.position.y) < 3.0:
			imported.position.y -= bounds.position.y
	for animation_node in imported.find_children("*", "AnimationPlayer", true, false):
		var player := animation_node as AnimationPlayer
		var animation_names := player.get_animation_list()
		if not animation_names.is_empty():
			var animation_name: StringName = animation_names[0]
			for candidate in animation_names:
				if candidate != &"RESET":
					animation_name = candidate
					break
			player.play(animation_name)
			var animation := player.get_animation(animation_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
	return imported

func _guest_limb(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color) -> Node3D:
	var pivot_node := Node3D.new()
	pivot_node.position = location
	parent.add_child(pivot_node)
	_make_box(pivot_node, Vector3(0, -dimensions.y * 0.5, 0), dimensions, color)
	return pivot_node

func _guest_visual(parent: Node3D) -> Dictionary:
	var visual := Node3D.new()
	parent.add_child(visual)
	if not guest_models.is_empty():
		var character_name: String = guest_models.keys().pick_random()
		var variants: Dictionary = guest_models[character_name]
		var imported_nodes: Dictionary = {}
		for motion in ["idle", "walk", "dance", "sit", "drink", "chat"]:
			if not variants.has(motion):
				continue
			var imported := _guest_animated_model(variants[motion], visual)
			if imported != null:
				imported.visible = motion == "walk"
				imported_nodes[motion] = imported
		if imported_nodes.has("walk") and imported_nodes.has("dance"):
			return {"visual": visual, "arms": [], "legs": [], "imported": true, "motions": imported_nodes, "motion": "walk", "character": character_name}
		for node in imported_nodes.values():
			(node as Node3D).queue_free()
	var jacket := Color.from_hsv(randf(), randf_range(0.12, 0.45), randf_range(0.22, 0.52))
	var trousers := Color("#20212d") if randf() < 0.7 else Color("#4c485a")
	var skin: Color = [Color("#e0b69b"), Color("#b77e62"), Color("#815444"), Color("#f1c9ad")].pick_random()
	_make_box(visual, Vector3(0, 0.71, 0), Vector3(0.29, 0.40, 0.19), jacket)
	_make_box(visual, Vector3(0, 0.98, 0), Vector3(0.17, 0.09, 0.15), skin)
	var head := SphereMesh.new()
	head.radius = 0.115
	head.height = 0.23
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head
	head_mesh.position.y = 1.08
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = skin
	head_mesh.material_override = head_material
	visual.add_child(head_mesh)
	var hair := Color("#17141a") if randf() < 0.55 else Color("#655046")
	_make_box(visual, Vector3(0, 1.185, -0.005), Vector3(0.23, 0.055, 0.22), hair)
	var arms: Array[Node3D] = []
	var legs: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		arms.append(_guest_limb(visual, Vector3(side * 0.19, 0.87, 0), Vector3(0.105, 0.37, 0.13), jacket))
		legs.append(_guest_limb(visual, Vector3(side * 0.085, 0.51, 0), Vector3(0.13, 0.48, 0.16), trousers))
	return {"visual": visual, "arms": arms, "legs": legs, "imported": false, "motions": {}, "motion": "walk"}

func _spawn_guest() -> void:
	if guests.size() >= MAX_GUESTS or not _walkable(GUEST_ENTRY) or _guest_too_close(_cell_position(GUEST_ENTRY), {}):
		return
	var destination := _dance_destination()
	if destination.x < 0:
		return
	var path := _path_to(GUEST_ENTRY, destination)
	if path.is_empty():
		return
	var person := Node3D.new()
	guest_layer.add_child(person)
	person.position = _cell_position(GUEST_ENTRY)
	var appearance := _guest_visual(person)
	guests.append({"node": person, "visual": appearance["visual"], "arms": appearance["arms"], "legs": appearance["legs"], "imported": appearance["imported"], "motions": appearance["motions"], "motion": "walk", "character": appearance.get("character", ""), "path": path, "dance": false, "phase": randf() * TAU, "speed": randf_range(1.25, 1.85), "state": "walk_dance", "cell": GUEST_ENTRY, "wait": randf_range(8.0, 16.0), "visits": 0, "destination": destination, "service_object": -1, "blocked_time": 0.0, "repath_cooldown": 0.0})
	guest_count += 1
	night_ticket_income += TICKET_PRICE
	cash += TICKET_PRICE
	_update_night_stats()
	_refresh_economy()
	_refresh_readiness()

func _service_destination(kind: String, start: Vector2i, guest: Dictionary) -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_object := -1
	var best_length := 999999
	for object_id in placed_objects:
		var record: Dictionary = placed_objects[object_id]
		if kind == "sofa":
			var reserved := false
			for other in guests:
				if other != guest and int(other.get("service_object", -1)) == int(object_id):
					reserved = true
					break
			if reserved:
				continue
		if str(record["kind"]) != kind:
			continue
		for furniture_cell in record["cells"]:
			for direction in WALK_DIRS:
				var candidate: Vector2i = furniture_cell + direction
				if not _walkable(candidate) or _destination_taken(candidate, guest):
					continue
				var path := _path_to(start, candidate)
				if candidate != start and path.is_empty():
					continue
				if path.size() < best_length:
					best = candidate
					best_object = int(object_id)
					best_length = path.size()
	return {"cell": best, "object": best_object}

func _guest_route(guest: Dictionary, kind: String) -> bool:
	var start: Vector2i = guest["cell"]
	var target := Vector2i(-1, -1)
	var service_object := -1
	if kind == "dance":
		target = _dance_destination()
	else:
		var service := _service_destination(kind, start, guest)
		target = service["cell"]
		service_object = int(service["object"])
	if target.x < 0:
		return false
	var path := _path_to(start, target)
	if target != start and path.is_empty():
		return false
	guest["path"] = path
	guest["destination"] = target
	guest["service_object"] = service_object
	guest["state"] = "walk_" + kind
	guest["blocked_time"] = 0.0
	guest["repath_cooldown"] = 0.0
	guest["dance"] = false
	return true

func _sofa_seat(approach_cell: Vector2i, object_id: int) -> Dictionary:
	var approach := _cell_position(approach_cell)
	var best_distance := INF
	var best: Dictionary = {}
	for record_id in placed_objects:
		if int(record_id) != object_id:
			continue
		var record: Dictionary = placed_objects[record_id]
		if str(record["kind"]) != "sofa":
			continue
		var sofa_node: Node3D = record["node"]
		var center := sofa_node.global_position + sofa_node.global_basis * Vector3(0.0, 0.0, 0.5)
		var distance := center.distance_squared_to(approach)
		if distance >= best_distance:
			continue
		best_distance = distance
		# Sit on the cushion rather than at the centre of the occupied grid.
		# Choose the side facing the aisle, independent of the sofa rotation.
		var toward_aisle := approach - center
		toward_aisle.y = 0.0
		if toward_aisle.length_squared() < 0.001:
			continue
		toward_aisle = toward_aisle.normalized()
		var seat := center + toward_aisle * 0.62
		seat.y = approach.y + 0.06
		best = {"position": seat, "rotation": atan2(toward_aisle.x, toward_aisle.z)}
	return best

func toward_seat_offset(angle: float, distance: float) -> Vector3:
	return Vector3(sin(angle), 0.0, cos(angle)) * distance

func _sit_animation_player(guest: Dictionary) -> AnimationPlayer:
	var motions: Dictionary = guest["motions"]
	if not motions.has("sit"):
		return null
	var model: Node3D = motions["sit"]
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer

func _play_sit(guest: Dictionary, backwards: bool) -> float:
	var player := _sit_animation_player(guest)
	if player == null:
		return 0.0
	var animation_name := player.current_animation
	if animation_name.is_empty():
		var names := player.get_animation_list()
		if names.is_empty():
			return 0.0
		animation_name = names[0]
	var animation := player.get_animation(animation_name)
	if animation == null:
		return 0.0
	animation.loop_mode = Animation.LOOP_NONE
	if backwards:
		player.play_backwards(animation_name)
	else:
		player.play(animation_name)
		player.seek(0.0, true)
	return animation.length

func _guest_arrived(guest: Dictionary) -> void:
	var state: String = guest["state"]
	if state == "walk_bar":
		guest["state"] = "ordering"
		guest["wait"] = randf_range(2.0, 4.0)
	elif state == "walk_sofa":
		guest["state"] = "resting"
		guest["wait"] = 2.0
		var motions: Dictionary = guest["motions"]
		if motions.has("sit"):
			var seat := _sofa_seat(guest["destination"], int(guest.get("service_object", -1)))
			if not seat.is_empty():
				var person: Node3D = guest["node"]
				guest["sofa_approach"] = person.position
				person.position = seat["position"]
				person.rotation.y = float(seat["rotation"])
				# All five character sit animations use the calibrated cushion anchor.
				person.position += toward_seat_offset(float(seat["rotation"]), 0.5)
				guest["seated"] = true
				guest["state"] = "sitting"
				guest["wait"] = _play_sit(guest, false)
	else:
		guest["state"] = "dancing"
		guest["dance"] = true
		guest["wait"] = randf_range(9.0, 17.0)

func _process(delta: float) -> void:
	_animate_stage_lights(delta)
	if not night_active or night_paused:
		return
	var step := delta * night_speed
	night_elapsed += step
	if night_elapsed >= NIGHT_DURATION:
		_end_night()
		return
	if night_time_label != null:
		var remaining := ceili(NIGHT_DURATION - night_elapsed)
		night_time_label.text = "TIME LEFT  %d:%02d  |  €%d TICKETS  €%d BAR" % [int(remaining / 60.0), remaining % 60, night_ticket_income, night_drink_income]
	guest_spawn_clock += step
	if guest_spawn_clock >= 5.0 and guests.size() < MAX_GUESTS:
		guest_spawn_clock = 0.0
		_spawn_guest()
	for guest in guests:
		var state: String = guest["state"]
		if state in ["dancing", "ordering", "resting", "sitting", "standing"]:
			guest["wait"] = float(guest["wait"]) - step
			if float(guest["wait"]) <= 0.0:
				if state == "sitting":
					guest["state"] = "resting"
					guest["wait"] = randf_range(5.0, 7.0)
				elif state == "resting" and bool(guest.get("seated", false)):
					guest["state"] = "standing"
					guest["wait"] = _play_sit(guest, true)
				elif state == "standing":
					var standing_person: Node3D = guest["node"]
					standing_person.position = guest["sofa_approach"]
					guest["seated"] = false
					if not _guest_route(guest, "dance"):
						guest["state"] = "dancing"
						guest["dance"] = true
						guest["wait"] = 5.0
				elif state == "ordering":
					night_drinks_sold += 1
					night_drink_income += DRINK_PRICE
					cash += DRINK_PRICE
					_update_night_stats()
					_refresh_economy()
					guest["visits"] = int(guest["visits"]) + 1
					if not _guest_route(guest, "dance"):
						guest["wait"] = 4.0
				elif state == "resting":
					if not _guest_route(guest, "dance"):
						guest["wait"] = 4.0
				else:
					var activity := "bar" if randf() < 0.65 and int(guest["visits"]) < 3 else "sofa"
					if not _guest_route(guest, activity):
						if not _guest_route(guest, "bar" if activity == "sofa" else "sofa"):
							guest["wait"] = 8.0
		var person: Node3D = guest["node"]
		if not is_instance_valid(person):
			continue
		guest["phase"] = float(guest["phase"]) + step * (5.0 if guest["dance"] else 8.0)
		var phase := float(guest["phase"])
		var visual: Node3D = guest["visual"]
		visual.position.y = 0.0 if bool(guest.get("seated", false)) else absf(sin(phase)) * (0.07 if guest["dance"] else 0.025)
		if not guest["imported"]:
			var arms: Array = guest["arms"]
			var legs: Array = guest["legs"]
			for index in range(2):
				var limb_side := 1.0 if index == 0 else -1.0
				(arms[index] as Node3D).rotation.x = sin(phase + float(index) * PI) * (0.65 if guest["dance"] else 0.35)
				(arms[index] as Node3D).rotation.z = limb_side * (0.4 if guest["dance"] else 0.08)
				(legs[index] as Node3D).rotation.x = sin(phase + float(index) * PI) * (0.23 if guest["dance"] else 0.45)
		if guest["imported"]:
			var desired_motion: String = "walk"
			var motions: Dictionary = guest["motions"]
			if bool(guest["dance"]):
				desired_motion = "dance"
			elif str(guest["state"]) in ["sitting", "resting", "standing"]:
				desired_motion = "sit" if motions.has("sit") else "idle"
			elif str(guest["state"]) == "ordering":
				if motions.has("drink"):
					desired_motion = "drink"
				elif motions.has("chat"):
					desired_motion = "chat"
				else:
					desired_motion = "idle"
			if not motions.has(desired_motion):
				desired_motion = "idle" if motions.has("idle") else "walk"
			if guest["motion"] != desired_motion:
				if desired_motion == "sit" and str(guest["state"]) == "sitting":
					_play_sit(guest, false)
				for motion_name in motions:
					(motions[motion_name] as Node3D).visible = motion_name == desired_motion
				guest["motion"] = desired_motion
		if guest["dance"]:
			person.rotation.y += step * 0.5
			visual.rotation.z = sin(phase * 0.5) * 0.11
			continue
		visual.rotation.z = 0.0
		if str(guest["state"]) in ["ordering", "resting", "sitting", "standing"]:
			continue
		var path: Array = guest["path"]
		if path.is_empty():
			_guest_arrived(guest)
			continue
		var target_cell: Vector2i = path[0]
		var target := _cell_position(target_cell)
		var direction := target - person.position
		if direction.length() < 0.07:
			path.pop_front()
			guest["cell"] = target_cell
			if path.is_empty():
				_guest_arrived(guest)
		else:
			var next_position := person.position.move_toward(target, float(guest["speed"]) * step)
			if _guest_too_close(next_position, guest):
				guest["blocked_time"] = float(guest.get("blocked_time", 0.0)) + step
				guest["repath_cooldown"] = maxf(0.0, float(guest.get("repath_cooldown", 0.0)) - step)
				if float(guest["blocked_time"]) >= 0.65 and float(guest["repath_cooldown"]) <= 0.0:
					var detour := _path_around_guests(guest["cell"], guest["destination"], guest)
					if not detour.is_empty():
						guest["path"] = detour
					guest["repath_cooldown"] = randf_range(0.7, 1.3)
				continue
			guest["blocked_time"] = 0.0
			person.position = next_position
			person.rotation.y = atan2(direction.x, direction.z)

func _clear_guests() -> void:
	for guest in guests:
		var person: Node3D = guest["node"]
		if is_instance_valid(person):
			person.queue_free()
	guests.clear()
	guest_spawn_clock = 0.0

func _build_bouncer() -> void:
	var path := "res://characters/bouncer.glb"
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var guard := packed.instantiate() as Node3D
	if guard == null:
		return
	guard.name = "EntranceBouncer"
	club.add_child(guard)
	guard.position = Vector3(1.35, 0.0, 8.2)
	guard.rotation.y = 0.0
	var bounds := _visual_bounds(guard)
	if bounds.size.y > 0.01:
		var scale_factor := clampf(0.64 / maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)), 0.01, 1.0)
		guard.scale = Vector3.ONE * scale_factor
		bounds = _visual_bounds(guard)
		guard.position.y -= bounds.position.y
	for animation_node in guard.find_children("*", "AnimationPlayer", true, false):
		var player := animation_node as AnimationPlayer
		for animation_name in player.get_animation_list():
			if animation_name != &"RESET":
				player.play(animation_name)
				break

func _disco_beam_material(opacity: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 beam_color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float opacity = 0.08;
void fragment() {
	float along = UV.y;
	float fade_start = smoothstep(0.0, 0.22, along);
	float fade_end = 1.0 - smoothstep(0.68, 1.0, along);
	float edge_softness = 0.35 + 0.65 * abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = beam_color.rgb;
	EMISSION = beam_color.rgb * 0.65;
	ALPHA = opacity * fade_start * fade_end * edge_softness;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("opacity", opacity)
	return material


func _attach_fixture_lighting(node: Node3D, kind: String) -> void:
	if kind not in ["light", "laser"] or not is_instance_valid(node):
		return
	if node.has_node("ClubSpot"):
		return
	var fixture: Node3D = node
	var spot := SpotLight3D.new()
	spot.name = "ClubSpot"
	# Laser emission begins at the projector lens, not above its housing.
	spot.position = Vector3(0.0, 0.12, 0.0) if kind == "laser" else Vector3(0.0, 0.77, -0.19)
	spot.spot_range = 14.0 if kind == "light" else 11.0
	spot.spot_angle = 25.0 if kind == "light" else 13.0
	spot.light_color = Color("#c15dff") if kind == "light" else LASER_COLORS[0]
	spot.light_energy = 4.0 if night_active else 0.0
	spot.shadow_enabled = false
	spot.light_volumetric_fog_energy = 6.0 if kind == "light" else 0.0
	fixture.add_child(spot)
	if kind == "light":
		# Each moving head gets its own small fog field, so beams are
		# visible even when the fixture is far from the global haze hotspots.
		var fog := FogVolume.new()
		fog.name = "FixtureHaze"
		fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fog.size = Vector3(3.2, 3.2, 8.0)
		fog.position = Vector3(0.0, 0.0, -3.5)
		var fog_material := FogMaterial.new()
		fog_material.density = 0.018
		fog_material.albedo = Color("#8c829e")
		fog.material = fog_material
		# Follow the spotlight's animated direction instead of the static fixture.
		spot.add_child(fog)
		fog.visible = night_active
	# Aim the beam from the projector toward the room, slightly upward.
	if kind == "laser":
		spot.look_at(Vector3(0.0, 2.4, 0.0), Vector3.UP)
	else:
		# The fixture's local +Z is the front of its lens.
		var forward := fixture.global_basis * Vector3(0.0, 0.0, 3.0)
		spot.look_at(spot.global_position + forward + Vector3.UP * 0.8, Vector3.UP)
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.012 if kind == "laser" else 0.035
	cone.bottom_radius = 0.62 if kind == "light" else 0.012
	cone.height = 7.0 if kind == "laser" else 3.8
	if kind == "light":
		cone.cap_top = false
		cone.cap_bottom = false
	beam.mesh = cone
	beam.rotation_degrees.x = 90.0
	beam.position = Vector3(0.0, 0.0, -3.5 if kind == "laser" else -1.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.25, 1.0, 0.09) if kind == "light" else Color(0.19, 1.0, 0.39, 0.95)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if kind == "light":
		beam.material_override = _disco_beam_material(0.12)
	else:
		beam.material_override = mat
	if kind == "laser":
		# Soft translucent halo around the bright, narrow laser core.
		var halo := MeshInstance3D.new()
		halo.name = "LaserHalo"
		var halo_mesh := CylinderMesh.new()
		halo_mesh.top_radius = 0.055
		halo_mesh.bottom_radius = 0.055
		halo_mesh.height = 7.0
		halo.mesh = halo_mesh
		var halo_mat := StandardMaterial3D.new()
		halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		halo_mat.albedo_color = Color(0.19, 1.0, 0.39, 0.12)
		halo.material_override = halo_mat
		beam.add_child(halo)
	if kind == "light":
		# A narrower luminous cone inside the broad atmospheric wash.
		var inner := MeshInstance3D.new()
		inner.name = "DiscoCore"
		var inner_mesh := CylinderMesh.new()
		inner_mesh.top_radius = 0.02
		inner_mesh.bottom_radius = 0.23
		inner_mesh.height = 3.8
		inner_mesh.cap_top = false
		inner_mesh.cap_bottom = false
		inner.mesh = inner_mesh
		var inner_mat := StandardMaterial3D.new()
		inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		inner_mat.albedo_color = Color(0.65, 0.35, 1.0, 0.18)
		inner.material_override = _disco_beam_material(0.19)
		beam.add_child(inner)
	spot.add_child(beam)
	# TEMP DIAGNOSTIC: show the actual spotlight axis for DJ-side heads.
	beam.visible = night_active and (kind == "laser" or (kind == "light" and fixture.position.z > 0.0 and absf(fixture.position.x) < 5.5))
	beam_meshes.append(beam)
	stage_lights.append(spot)
	if kind == "light":
		disco_spots.append(spot)
	if kind == "laser":
		laser_spots.append(spot)
		laser_beams.append(beam)


func _build_stage_lights() -> void:
	for record in placed_objects.values():
		_attach_fixture_lighting(record["node"] as Node3D, str(record["kind"]))
	# Evenly cover the entire 10 x 7 tile dance floor with overlapping
	# moving pools of colored light rather than leaving dark corners.
	for row_index in range(3):
		for column_index in range(4):
			var index := row_index * 4 + column_index
			var glow := OmniLight3D.new()
			glow.position = Vector3(-3.45 + float(column_index) * 2.3, 0.75, -3.65 + float(row_index) * 2.3)
			glow.omni_range = 3.2
			glow.light_color = Color.from_hsv(fmod(0.73 + float(index) * 0.075, 1.0), 0.8, 1.0)
			glow.light_energy = 0.0
			glow.shadow_enabled = false
			club.add_child(glow)
			dance_lights.append(glow)

func _debug_fixture_lights() -> void:
	var live := 0
	for spot in disco_spots:
		if not is_instance_valid(spot):
			continue
		live += 1
		var direction := -spot.global_basis.z
		var haze := spot.get_node_or_null("FixtureHaze") as FogVolume
		print("LIGHT DEBUG | %s | pos=%s | dir=%s | energy=%.2f | volumetric=%.2f | haze=%s | visible=%s" % [
			spot.get_parent().name, str(spot.global_position), str(direction),
			spot.light_energy, spot.light_volumetric_fog_energy,
			str(haze != null), str(spot.visible)
		])
	print("LIGHT DEBUG | registered=%d active=%d lasers=%d" % [disco_spots.size(), live, laser_spots.size()])


func _set_night_lighting(enabled: bool) -> void:
	if club_environment != null:
		club_environment.ambient_light_energy = 0.48 if enabled else 0.85
		club_environment.background_color = Color("#080b18") if enabled else Color("#131a2b")
		club_environment.volumetric_fog_enabled = enabled
	if club_sun != null:
		club_sun.light_energy = 0.33 if enabled else 1.0
	for spot in stage_lights:
		if is_instance_valid(spot):
			spot.light_energy = 4.0 if enabled else 0.0
			var fixture := spot.get_parent() as Node3D
			var haze := spot.get_node_or_null("FixtureHaze") as FogVolume
			if haze != null:
				haze.visible = enabled
	for beam in beam_meshes:
		if is_instance_valid(beam):
			# Only lasers use geometry; moving-head beams come from volumetric fog.
			var fixture := beam.get_parent().get_parent() as Node3D
			var is_dj_light := fixture.name.begins_with("light_") and fixture.position.z > 0.0 and absf(fixture.position.x) < 5.5
			beam.visible = enabled and (beam.get_node_or_null("LaserHalo") != null or is_dj_light)
	for glow in dance_lights:
		if is_instance_valid(glow):
			glow.light_energy = 1.2 if enabled else 0.0
	if enabled:
		_debug_fixture_lights()

func _animate_stage_lights(delta: float) -> void:
	if not night_active or night_paused:
		return
	lighting_clock += delta * night_speed
	for index in range(stage_lights.size()):
		var spot := stage_lights[index]
		if not is_instance_valid(spot):
			continue
		var phase := lighting_clock * (0.8 + float(index % 4) * 0.17) + float(index) * 1.7
		if laser_spots.has(spot):
			var aim := Vector3(sin(phase) * 1.8, 2.4 + sin(phase * 0.7) * 0.45, cos(phase * 0.8) * 1.8)
			spot.look_at(aim, Vector3.UP)
		else:
			# Rotate the beam with the placed fixture, never toward club center.
			var fixture := spot.get_parent() as Node3D
			var local_direction := Vector3(sin(phase) * 0.65, 0.8 + sin(phase * 0.7) * 0.25, 3.0)
			var direction := fixture.global_basis * local_direction
			spot.look_at(spot.global_position + direction, Vector3.UP)
		spot.light_energy = 3.0 + 2.0 * (0.5 + 0.5 * sin(lighting_clock * 3.0 + float(index)))
	# Independent color changes and a restrained rhythmic flash for moving heads.
	for index in range(disco_spots.size()):
		var disco := disco_spots[index]
		if not is_instance_valid(disco):
			continue
		var palette_index := (int(floor(lighting_clock / 5.0)) + index * 2) % DISCO_COLORS.size()
		var color: Color = DISCO_COLORS[palette_index]
		disco.light_color = color
		var beat := pow(maxf(0.0, sin(lighting_clock * 4.0 + float(index) * 1.7)), 8.0)
		disco.light_energy = 3.2 + 2.2 * beat
		var cone := disco.get_node_or_null("VisibleBeam") as MeshInstance3D
		if cone == null:
			# Older beams are unnamed; locate the first mesh child.
			for child in disco.get_children():
				if child is MeshInstance3D:
					cone = child as MeshInstance3D
					break
		if cone != null:
			var outer_mat := cone.material_override as ShaderMaterial
			if outer_mat != null:
				outer_mat.set_shader_parameter("beam_color", color)
				outer_mat.set_shader_parameter("opacity", 0.11 + 0.04 * beat)
			var inner := cone.get_node_or_null("DiscoCore") as MeshInstance3D
			if inner != null:
				var inner_material := inner.material_override as ShaderMaterial
				if inner_material != null:
					inner_material.set_shader_parameter("beam_color", color)
					inner_material.set_shader_parameter("opacity", 0.17 + 0.07 * beat)
	# Each light has a different phase; no part of the floor goes fully dark.
	for index in range(dance_lights.size()):
		var glow := dance_lights[index]
		if not is_instance_valid(glow):
			continue
		var phase := lighting_clock * 2.1 + float(index) * 0.85
		glow.light_energy = 1.15 + 1.65 * (0.5 + 0.5 * sin(phase))
		glow.light_color = Color.from_hsv(fmod(0.72 + float(index) * 0.075 + lighting_clock * 0.018, 1.0), 0.8, 1.0)
	# Cycle laser colors every four seconds, with a stagger per fixture.
	for index in range(laser_spots.size()):
		var color_index := (int(floor(lighting_clock / 4.0)) + index) % LASER_COLORS.size()
		var laser_color: Color = LASER_COLORS[color_index]
		var laser := laser_spots[index]
		if is_instance_valid(laser):
			laser.light_color = laser_color
		var beam := laser_beams[index]
		if is_instance_valid(beam):
			var material := beam.material_override as StandardMaterial3D
			if material != null:
				var beam_color := laser_color
				beam_color.a = 0.95
				material.albedo_color = beam_color
			var halo := beam.get_node_or_null("LaserHalo") as MeshInstance3D
			if halo != null:
				var halo_material := halo.material_override as StandardMaterial3D
				if halo_material != null:
					var halo_color := laser_color
					halo_color.a = 0.12
					halo_material.albedo_color = halo_color


func _start_night() -> void:
	_refresh_readiness()
	if night_active or not _readiness_issues().is_empty() or dj_picker.selected < 0:
		return
	var dj: Dictionary = DJ_ROSTER[dj_picker.selected]
	var fee := int(dj["fee"])
	cash -= fee
	night_dj_fee = fee
	night_elapsed = 0.0
	night_paused = false
	night_speed = 1.0
	night_ticket_income = 0
	night_drink_income = 0
	night_drinks_sold = 0
	if night_report_panel != null:
		night_report_panel.show()
	_update_night_stats()
	night_number += 1
	night_active = true
	_set_night_lighting(true)
	night_report_panel.show()
	_clear_guests()
	guest_count = 0
	build_mode = false
	erase_mode = false
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())
	_refresh_economy()
	_refresh_readiness()
	_notify("NIGHT %d  |  %s booked  |  -€%d" % [night_number, dj["name"], fee])
	start_night_button.text = "END NIGHT"
	night_pause_button.disabled = false
	night_speed_button.disabled = false
	night_pause_button.text = "PAUSE"
	night_speed_button.text = "1× SPEED"
	night_time_label.text = "TIME LEFT  3:00  |  €0 TICKETS  €0 BAR"

func _end_night() -> void:
	if not night_active:
		return
	night_active = false
	_set_night_lighting(false)
	var costs := night_dj_fee + STAFF_COST
	cash -= STAFF_COST
	_clear_guests()
	_refresh_economy()
	night_pause_button.disabled = true
	night_speed_button.disabled = true
	night_time_label.text = "NIGHT COMPLETE"
	var revenue := night_ticket_income + night_drink_income
	var profit := revenue - costs
	_update_night_stats()
	start_night_button.text = "START NIGHT"
	_refresh_readiness()
	_notify("Night %d ended  |  %d guests visited  |  Profit %s€%d" % [night_number, guest_count, "+" if profit >= 0 else "-", absi(profit)])

func _update_night_stats() -> void:
	if night_report_details == null:
		return
	var revenue := night_ticket_income + night_drink_income
	var expenses := night_dj_fee + STAFF_COST
	var profit := revenue - expenses
	night_report_heading.text = "NIGHT %d  |  %s" % [night_number, "LIVE STATS" if night_active else "REPORT"]
	night_report_details.text = "GUESTS                 %d\nTICKET REVENUE    €%d\nDRINKS SOLD          %d\nBAR REVENUE        €%d\n\nTOTAL REVENUE     €%d\nDJ BOOKING           -€%d\nSTAFF                      -€%d\n\nNET PROFIT             %s€%d" % [guest_count, night_ticket_income, night_drinks_sold, night_drink_income, revenue, night_dj_fee, STAFF_COST, "+" if profit >= 0 else "-", absi(profit)]

func _night_button_pressed() -> void:
	if night_active:
		_end_night()
	else:
		_start_night()

func _notify(message: String) -> void:
	if notice_label != null:
		notice_label.text = message

func _remove_object(id: int) -> Dictionary:
	if not placed_objects.has(id):
		return {}
	var record: Dictionary = placed_objects[id]
	for cell in record["cells"]:
		occupied.erase(cell)
		object_at_cell.erase(cell)
	var node := record["node"] as Node3D
	if is_instance_valid(node):
		var attached_spot := node.get_node_or_null("ClubSpot") as SpotLight3D
		if attached_spot != null:
			stage_lights.erase(attached_spot)
			disco_spots.erase(attached_spot)
			laser_spots.erase(attached_spot)
			for child in attached_spot.get_children():
				if child is MeshInstance3D:
					beam_meshes.erase(child)
					laser_beams.erase(child)
		node.get_parent().remove_child(node)
		node.queue_free()
	placed_objects.erase(id)
	return {"kind": record["kind"], "x": record["x"], "y": record["y"], "turn": record["turn"], "paid": record.get("paid", false)}

func _erase_hovered() -> void:
	if night_active:
		_notify("Finish the night before editing")
		return
	var id: int = int(object_at_cell.get(hover_cell, -1))
	if id < 0:
		return
	var record := _remove_object(id)
	if not record.is_empty():
		var refund: int = int(int(BUILD_PRICES.get(record["kind"], 0)) / 2.0) if bool(record["paid"]) else 0
		cash += refund
		action_history.append({"action": "erase", "record": record, "refund": refund})
		_refresh_economy()
		_notify("Removed %s  |  Refund €%d" % [str(record["kind"]).capitalize(), refund])
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _undo_action() -> void:
	if night_active:
		return
	if action_history.is_empty():
		return
	var action: Dictionary = action_history.pop_back()
	if action["action"] == "place":
		var removed := _remove_object(int(action["id"]))
		if not removed.is_empty():
			cash += int(action["cost"])
			_notify("Placement undone  |  €%d returned" % int(action["cost"]))
	elif action["action"] == "erase":
		var record: Dictionary = action["record"]
		var node := _model(club, record["kind"], record["x"], record["y"], record["turn"])
		var restored_id := _register_object(node, record["kind"], record["x"], record["y"], record["turn"])
		_attach_fixture_lighting(node, str(record["kind"]))
		placed_objects[restored_id]["paid"] = record["paid"]
		cash -= int(action["refund"])
		_notify("Removal undone")
	_refresh_economy()
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _reserve(x: int, y: int) -> void:
	occupied[Vector2i(x, y)] = true

func _footprint(x: int, y: int, kind: String, turn: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i(x, y)]
	if kind in TWO_CELL:
		var offsets := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
		cells.append(Vector2i(x, y) + offsets[posmod(turn, 4)])
	return cells

func _can_place(x: int, y: int, kind: String = "speaker", turn: int = 0) -> bool:
	for cell in _footprint(x, y, kind, turn):
		if cell.x <= 0 or cell.y <= 0 or cell.x >= SIZE - 1 or cell.y >= SIZE - 1 or occupied.has(cell):
			return false
	return true

func _build_hover() -> void:
	hover_mesh = _make_box(self, Vector3.ZERO, Vector3(0.96, 0.025, 0.96), Color(0.2, 1.0, 0.55, 0.4))
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	hover_mesh.material_override = mat
	hover_mesh.visible = false
	preview_root = Node3D.new()
	preview_root.name = "BuildPreview"
	add_child(preview_root)

func _refresh_preview() -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	if not build_mode or erase_mode or hover_cell.x < 0 or hover_cell.y < 0 or hover_cell.x >= SIZE or hover_cell.y >= SIZE:
		return
	var node := _model(preview_root, selected_kind, hover_cell.x, hover_cell.y, build_turn)
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.albedo_color = Color(0.25, 1.0, 0.6, 0.32) if _can_place(hover_cell.x, hover_cell.y, selected_kind, build_turn) else Color(1.0, 0.2, 0.3, 0.35)
		mesh.material_overlay = overlay

func _update_hover(screen_pos: Vector2) -> void:
	if not build_mode or (build_panel != null and build_panel.visible and build_panel.get_global_rect().has_point(screen_pos)) or (build_toggle != null and build_toggle.get_global_rect().has_point(screen_pos)):
		hover_mesh.visible = false
		preview_root.visible = false
		return
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		hover_mesh.visible = false
		preview_root.visible = false
		return
	var distance := -origin.y / direction.y
	if distance < 0.0:
		hover_mesh.visible = false
		preview_root.visible = false
		return
	var hit := origin + direction * distance
	var x := roundi(hit.x + 7.5)
	var y := roundi(hit.z + 7.5)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		hover_mesh.visible = false
		preview_root.visible = false
		hover_cell = Vector2i(-1, -1)
		return
	var next_cell := Vector2i(x, y)
	var changed := next_cell != hover_cell
	hover_cell = next_cell
	hover_mesh.visible = true
	preview_root.visible = true
	hover_mesh.position = Vector3(x - 7.5, float(floor_heights.get(next_cell, 0.0)) + 0.035, y - 7.5)
	var mat := hover_mesh.material_override as StandardMaterial3D
	mat.albedo_color = (Color(1.0, 0.35, 0.2, 0.45) if object_at_cell.has(next_cell) else Color(0.5, 0.5, 0.5, 0.25)) if erase_mode else (Color(0.2, 1.0, 0.55, 0.4) if _can_place(x, y, selected_kind, build_turn) else Color(1.0, 0.25, 0.3, 0.4))
	if changed:
		_refresh_preview()

func _place_selected() -> void:
	if not _can_place(hover_cell.x, hover_cell.y, selected_kind, build_turn):
		return
	if night_active:
		_notify("Finish the night before building")
		return
	var cost := int(BUILD_PRICES.get(selected_kind, 0))
	if cash < cost:
		_notify("Not enough cash  |  Need €%d" % cost)
		return
	var node := _model(club, selected_kind, hover_cell.x, hover_cell.y, build_turn)
	var id := _register_object(node, selected_kind, hover_cell.x, hover_cell.y, build_turn)
	_attach_fixture_lighting(node, selected_kind)
	placed_objects[id]["paid"] = true
	cash -= cost
	action_history.append({"action": "place", "id": id, "cost": cost})
	_refresh_economy()
	_notify("Built %s  |  -€%d" % [selected_kind.capitalize(), cost])
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _enable_erase() -> void:
	if night_active:
		return
	build_mode = true
	erase_mode = true
	dragging = false
	status_label.text = "ERASE MODE  |  Click: remove  X: build  Ctrl/Cmd+Z: undo"
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _toggle_build_panel() -> void:
	build_panel.visible = not build_panel.visible
	build_toggle.text = "CLOSE BUILD" if build_panel.visible else "BUILD  [B]"
	_update_hover(get_viewport().get_mouse_position())

func _toggle_help() -> void:
	help_label.visible = not help_label.visible

func _choose_kind(kind: String) -> void:
	if night_active:
		return
	selected_kind = kind
	erase_mode = false
	build_mode = true
	dragging = false
	status_label.text = "BUILD: %s  |  Click: place  R: rotate  ESC: exit" % selected_kind.to_upper()
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _build_world() -> void:
	_load_models()
	club = Node3D.new()
	club.name = "ABLETON_GYM"
	add_child(club)
	var dark := Color("#272735")
	var light := Color("#343342")
	var dance_color := Color("#6a3b7d")
	for y in range(SIZE):
		for x in range(SIZE):
			var dance := x >= 3 and x <= 12 and y >= 3 and y <= 9
			if dance and models.has("floor"):
				_model(club, "floor", x, y)
				continue
			_make_box(club, Vector3(x - 7.5, 0.025 if dance else -0.055, y - 7.5),
				Vector3(0.99, 0.15 if dance else 0.10, 0.99),
				dance_color if dance else (dark if (x + y) % 2 == 0 else light))
			floor_heights[Vector2i(x, y)] = 0.10 if dance else -0.005
	# Original saved ABLETON GYM layout, including rotations.
	var items := [
		[6,0,"poster",0],[0,4,"poster",0],[0,12,"poster",0],[15,12,"poster",0],
		[1,1,"light",0],[3,1,"sofa",3],[4,1,"plant2",0],[5,1,"laser",0],[7,1,"table",0],
		[9,1,"laser",0],[10,1,"plant2",0],[12,1,"bar",3],[14,1,"light",0],
		[6,2,"speaker",0],[8,2,"speaker",0],[1,3,"plant2",0],[14,3,"plant2",0],
		[14,5,"sofa",2],[1,6,"plant2",0],[14,6,"table",0],[1,7,"laser",1],
		[14,8,"sofa",2],[1,8,"bar",0],[2,9,"stool",0],[14,9,"plant2",0],
		[1,10,"laser",1],[5,10,"light",2],[7,10,"dj",1],[10,10,"light",2],
		[1,11,"plant2",0],[14,10,"plant2",0],[14,11,"plant2",0],
		[2,13,"stool",0],[11,13,"stool",0],[1,14,"light",2],[2,14,"bar",1],
		[5,14,"speaker",2],[10,14,"speaker",2],[11,14,"bar",1],[13,14,"wc",1]
	]
	for y in range(SIZE):
		for x in range(SIZE):
			if x == 0 or x == SIZE - 1 or y == 0 or y == SIZE - 1:
				if y == SIZE - 1 and (x == 7 or x == 8):
					continue
				var is_poster := (x == 6 and y == 0) or (x == 0 and y in [4,12]) or (x == 15 and y == 12)
				if not is_poster:
					_model(club, "wall", x, y, 1 if x == 0 or x == SIZE - 1 else 0)
	for item in items:
		var node := _model(club, item[2], item[0], item[1], item[3])
		_register_object(node, item[2], item[0], item[1], item[3])
	_model(club, "entrance", 7, 15, 1)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#131a2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d4c7ed")
	env.ambient_light_energy = 0.85
	# Forward+ volumetric haze: low density keeps the club readable.
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.075
	env.volumetric_fog_albedo = Color("#8c829e")
	env.volumetric_fog_emission = Color("#08050e")
	env.volumetric_fog_emission_energy = 0.15
	env.volumetric_fog_anisotropy = 0.55
	club_environment = env
	ambient.environment = env
	add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	club_sun = sun
	add_child(sun)
	_build_stage_lights()
	_build_bouncer()

func _build_camera() -> void:
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	add_child(pivot)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom
	camera.position = Vector3(0, 0, 22)
	pivot.add_child(camera)
	_update_camera()

func _update_camera() -> void:
	pivot.rotation = Vector3(tilt, yaw, 0)
	camera.size = zoom

func _build_overlay() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "ABLETON GYM"
	UIStyle.decorate_label(title, 23)
	title.position = Vector2(20, 20)
	
	ui.add_child(title)
	if not missing_models.is_empty():
		var warning := Label.new()
		warning.text = "Missing GLB: " + ", ".join(missing_models)
		warning.position = Vector2(300, 120)
		warning.add_theme_color_override("font_color", Color("#ffb27c"))
		ui.add_child(warning)
	economy_label = Label.new()
	economy_label.position = Vector2(20, 57)
	UIStyle.decorate_label(economy_label, 18)
	ui.add_child(economy_label)
	_refresh_economy()
	notice_label = Label.new()
	notice_label.position = Vector2(20, 86)
	UIStyle.decorate_label(notice_label, 13, true)
	ui.add_child(notice_label)
	status_label = Label.new()
	status_label.position = Vector2(20, 113)
	status_label.text = "MODE: CAMERA   |   B: build   X: erase   Ctrl/Cmd+Z: undo"
	UIStyle.decorate_label(status_label, 13, true)
	ui.add_child(status_label)
	build_toggle = Button.new()
	build_toggle.text = "BUILD  [B]"
	build_toggle.position = Vector2(20, 151)
	build_toggle.custom_minimum_size = Vector2(166, 38)
	UIStyle.decorate_button(build_toggle, true)
	build_toggle.pressed.connect(_toggle_build_panel)
	ui.add_child(build_toggle)
	build_panel = PanelContainer.new()
	build_panel.position = Vector2(20, 198)
	build_panel.visible = false
	UIStyle.decorate_panel(build_panel)
	ui.add_child(build_panel)
	var choices := GridContainer.new()
	choices.columns = 2
	build_panel.add_child(choices)
	for kind in BUILD_TYPES:
		var button := Button.new()
		button.text = "%s   €%d" % [{"dj": "DJ Booth", "wc": "Restroom", "plant2": "Plant", "light": "Moving Light"}.get(kind, kind.capitalize()), int(BUILD_PRICES.get(kind, 0))]
		button.custom_minimum_size = Vector2(142, 34)
		UIStyle.decorate_button(button)
		button.pressed.connect(_choose_kind.bind(kind))
		choices.add_child(button)
	var erase_button := Button.new()
	erase_button.text = "ERASE  [X]"
	UIStyle.decorate_button(erase_button)
	erase_button.pressed.connect(_enable_erase)
	choices.add_child(erase_button)
	var night_panel := PanelContainer.new()
	night_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	night_panel.offset_left = -315
	night_panel.offset_right = -20
	night_panel.offset_top = 20
	night_panel.offset_bottom = 20
	UIStyle.decorate_panel(night_panel)
	night_panel.custom_minimum_size = Vector2(275, 0)
	ui.add_child(night_panel)
	var night_controls := VBoxContainer.new()
	night_panel.add_child(night_controls)
	var heading := Label.new()
	heading.text = "CLUB OPENING"
	UIStyle.decorate_label(heading, 19)
	night_controls.add_child(heading)
	readiness_label = Label.new()
	readiness_label.custom_minimum_size = Vector2(255, 40)
	UIStyle.decorate_label(readiness_label, 14)
	readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	night_controls.add_child(readiness_label)
	var dj_label := Label.new()
	dj_label.text = "BOOK A DJ"
	UIStyle.decorate_label(dj_label, 13, true)
	night_controls.add_child(dj_label)
	dj_picker = OptionButton.new()
	for dj in DJ_ROSTER:
		dj_picker.add_item("%s  •  €%d" % [dj["name"], dj["fee"]])
	dj_picker.selected = 0
	dj_picker.item_selected.connect(func(_index: int) -> void: _refresh_readiness())
	night_controls.add_child(dj_picker)
	start_night_button = Button.new()
	start_night_button.text = "START NIGHT"
	UIStyle.decorate_button(start_night_button, true)
	start_night_button.pressed.connect(_night_button_pressed)
	start_night_button.custom_minimum_size = Vector2(255, 48)
	night_controls.add_child(start_night_button)
	night_time_label = Label.new()
	night_time_label.text = "3-MINUTE NIGHT  |  TICKETS €20  |  DRINKS €8"
	UIStyle.decorate_label(night_time_label, 12, true)
	night_controls.add_child(night_time_label)
	var speed_controls := HBoxContainer.new()
	night_controls.add_child(speed_controls)
	night_pause_button = Button.new()
	night_pause_button.text = "PAUSE"
	night_pause_button.disabled = true
	UIStyle.decorate_button(night_pause_button)
	night_pause_button.pressed.connect(func() -> void:
		night_paused = not night_paused
		night_pause_button.text = "RESUME" if night_paused else "PAUSE"
	)
	speed_controls.add_child(night_pause_button)
	night_speed_button = Button.new()
	night_speed_button.text = "1× SPEED"
	night_speed_button.disabled = true
	UIStyle.decorate_button(night_speed_button)
	night_speed_button.pressed.connect(func() -> void:
		night_speed = 2.0 if night_speed == 1.0 else 1.0
		night_speed_button.text = "2× SPEED" if night_speed == 2.0 else "1× SPEED"
	)
	speed_controls.add_child(night_speed_button)
	night_report_panel = PanelContainer.new()
	night_report_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	night_report_panel.offset_left = -315
	night_report_panel.offset_right = -20
	night_report_panel.offset_top = 300
	night_report_panel.offset_bottom = 300
	night_report_panel.custom_minimum_size = Vector2(275, 0)
	night_report_panel.visible = false
	UIStyle.decorate_panel(night_report_panel)
	ui.add_child(night_report_panel)
	var report_content := VBoxContainer.new()
	night_report_panel.add_child(report_content)
	night_report_heading = Label.new()
	UIStyle.decorate_label(night_report_heading, 18)
	report_content.add_child(night_report_heading)
	night_report_details = Label.new()
	UIStyle.decorate_label(night_report_details, 13)
	report_content.add_child(night_report_details)
	_refresh_readiness()
	var help_button := Button.new()
	help_button.text = "?  HELP"
	help_button.position = Vector2(20, 205)
	UIStyle.decorate_button(help_button)
	help_button.pressed.connect(_toggle_help)
	ui.add_child(help_button)
	help_label = Label.new()
	help_label.text = "Drag: rotate   Shift+drag: pan\nWheel/pinch or +/-: zoom\nR: rotate furniture / reset camera\nB: build   X: erase   Ctrl/Cmd+Z: undo"
	help_label.position = Vector2(20, 250)
	help_label.visible = false
	UIStyle.decorate_label(help_label, 13, true)
	ui.add_child(help_label)

func _input(event: InputEvent) -> void:
	# Handle scrolling even when a UI Control consumes unhandled input.
	if event is InputEventMagnifyGesture:
		zoom = clamp(zoom / maxf(event.factor, 0.01), MIN_ZOOM, MAX_ZOOM)
		_update_camera()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		# macOS trackpad scrolling must zoom; camera rotation stays on mouse drag.
		if absf(event.delta.y) > 0.001:
			zoom = clampf(zoom * exp(event.delta.y * 0.055), MIN_ZOOM, MAX_ZOOM)
			_update_camera()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and build_mode:
		_update_hover(event.position)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				# Standard mouse wheel: some devices report factor=0.
				var steps := maxf(event.factor, 1.0)
				var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				zoom = clampf(zoom * pow(1.12, direction * steps), MIN_ZOOM, MAX_ZOOM)
				_update_camera()
				get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and build_mode:
			if event.pressed and not (build_panel.visible and build_panel.get_global_rect().has_point(event.position)) and not build_toggle.get_global_rect().has_point(event.position) and not night_active:
				_update_hover(event.position)
				if erase_mode:
					_erase_hovered()
				else:
					_place_selected()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var over_ui := false
				if build_toggle != null and build_toggle.get_global_rect().has_point(event.position):
					over_ui = true
				if build_panel != null and build_panel.visible and build_panel.get_global_rect().has_point(event.position):
					over_ui = true
				dragging = not over_ui
			else:
				dragging = false
			last_mouse = event.position
	elif event is InputEventMouseMotion and dragging:
		var delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		if Input.is_key_pressed(KEY_SHIFT):
			pivot.position += pivot.basis.x * (-delta.x * 0.012) + Vector3(0, 0, 1) * (-delta.y * 0.012)
		else:
			yaw -= delta.x * 0.007
			tilt = clamp(tilt + delta.y * 0.005, deg_to_rad(-85), deg_to_rad(-20))
			_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
		_undo_action()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X and not night_active:
		if erase_mode:
			erase_mode = false
			status_label.text = "BUILD: %s  |  Click: place  R: rotate  ESC: exit" % selected_kind.to_upper()
			_refresh_preview()
			_update_hover(get_viewport().get_mouse_position())
		else:
			_enable_erase()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B and not night_active:
		build_mode = not build_mode
		if not build_mode:
			erase_mode = false
		dragging = false
		status_label.text = ("BUILD: %s  |  Click: place  R: rotate  ESC: exit" % selected_kind.to_upper()) if build_mode else "MODE: CAMERA   |   B: build   ESC: camera"
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		build_mode = false
		erase_mode = false
		dragging = false
		status_label.text = "MODE: CAMERA   |   B: build   ESC: camera"
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD):
		zoom = max(MIN_ZOOM, zoom * 0.85)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT):
		zoom = min(MAX_ZOOM, zoom * 1.15)
		_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and build_mode and not erase_mode:
		build_turn = (build_turn + 1) % 4
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = deg_to_rad(45)
		tilt = deg_to_rad(-55)
		zoom = 16
		pivot.position = Vector3.ZERO
		_update_camera()
