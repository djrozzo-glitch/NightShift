extends Node3D
const UIStyle = preload("res://scripts/ui_style.gd")
## First migration milestone: a playable 3D camera and procedural club shell.
## Controls: left-drag rotate, shift+left-drag pan, wheel zoom, R reset.

const SIZE := 16
const EXPANDED_WIDTH := 22
const EXPANSION_PRICE := 5000
var grid_width := SIZE
var expanded := false
var expansion_button: Button
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
var dance_tiles: Dictionary = {}
var free_dance_tiles := 0
var hover_cell := Vector2i(-1, -1)
var hover_mesh: MeshInstance3D
var status_label: Label
const BUILD_TYPES := ["dance_tile", "speaker", "dj", "bar", "sofa", "wc", "table", "stool", "plant2", "light", "laser", "rail"]
var selected_kind := "speaker"
var build_turn := 0
var preview_root: Node3D
var build_panel: PanelContainer
var catalog_buttons: Dictionary = {}
var build_toggle: Button
var help_label: Label
var erase_mode := false
var moving_object_id := -1
var moving_dance_tile := Vector2i(-1, -1)
var moving_turn := 0
var build_kind_selected := false
var rotate_object_button: Button
var object_drag_armed := false
var object_dragging := false
var object_drag_start := Vector2.ZERO
var placed_objects: Dictionary = {}
var object_at_cell: Dictionary = {}
var next_object_id := 1
var action_history: Array[Dictionary] = []
# Prototype economy: prices and starting balance will be balanced later.
const BUILD_PRICES := {"dance_tile": 70, "speaker": 300, "dj": 1200, "bar": 850, "sofa": 400, "wc": 650, "table": 100, "stool": 75, "plant2": 90, "light": 250, "laser": 450, "rail": 180}
const STARTING_CAPITAL := 6000
var cash := STARTING_CAPITAL
var reputation := 55
var club_level := 1
var club_xp := 0
var total_xp := 0
var perk_points := 0
var unlocked_perks: Array[String] = []
var progression_panel: PanelContainer
var xp_bar: ProgressBar
var rep_bar: ProgressBar
var progression_details: Label
var perk_buttons: Array[Button] = []
var expansion_details: Label
var management_panel: PanelContainer
const SAVE_PATH := "user://nightshift_club.json"
const LEVEL_NAMES := ["Illegal Basement", "Word of Mouth", "Local Favorite", "Afterhours", "Underground Institution", "Citywide Buzz", "Cult Following", "Scene Leader", "International Attention", "Legendary Venue"]
const LEVEL_UNLOCKS := {"stool": 3, "plant2": 5, "laser": 2, "sofa": 3, "table": 4, "rail": 4}
const BUILD_NAMES := {"dance_tile": "Dance Tile", "dj": "DJ Booth", "wc": "Restroom", "plant2": "Plant", "light": "Moving Light"}
const PERK_OPTIONS := [
	{"id": "connections", "name": "Local Connections", "effect": "-5% DJ fees", "branch": "MUSIC"},
	{"id": "resident", "name": "Resident Deal", "effect": "-10% DJ fees", "branch": "MUSIC"},
	{"id": "lineups", "name": "Better Lineups", "effect": "+8% attendance", "branch": "MUSIC"},
	{"id": "happy", "name": "Happy Hour", "effect": "+5% bar revenue", "branch": "BAR"},
	{"id": "premium", "name": "Premium Drinks", "effect": "+10% bar revenue", "branch": "BAR"},
	{"id": "word", "name": "Word of Mouth", "effect": "+5% attendance", "branch": "COMMUNITY"},
	{"id": "regulars", "name": "Regular Crowd", "effect": "+10% attendance", "branch": "COMMUNITY"}
]
var last_rep_change := 0
var last_xp_gain := 0
var completed_milestones: Array[String] = []
var profitable_night_streak := 0
const CLUB_MILESTONES := [
	{"id": "first_profit", "name": "FIRST PROFIT", "reward": 150},
	{"id": "full_house", "name": "PACKED BASEMENT", "reward": 200},
	{"id": "drinks_30", "name": "BAR IS BOOMING", "reward": 150},
	{"id": "profit_streak", "name": "THREE GOOD NIGHTS", "reward": 250}
]
var economy_label: Label
var notice_label: Label
var readiness_label: Label
var dj_picker: OptionButton
var start_night_button: Button
var night_active := false
var night_number := 0
var guest_layer: Node3D
const RAVER_THOUGHTS := {
	"thirst": ["Need water before the next drop.","That bar looks like salvation.","My mouth is basically concrete.","One drink and I'm back in orbit.","Where did I leave my water?","The bass is dry, so am I.","I could drink the whole ice bucket.","Bar queue, please move.","A cold drink would fix everything.","Even ravers need hydration."],
	"tired": ["My legs are filing a complaint.","That sofa is calling my name.","One more track, then I sit.","I need five minutes off the floor.","Who invented knees anyway?","My sneakers have seen too much.","A little rest and I'll be fine.","The kick is strong; I am not.","I could sleep standing up.","Maybe the chillout corner is free."],
	"happy": ["This groove is ridiculous.","I could stay here forever.","Who needs daylight?","The room is absolutely locked in.","This is why we go out.","That bassline just rewired me.","I love this tiny sweaty universe.","Nobody's filming. Perfect.","Best night I've had in ages.","The DJ gets it."],
	"unhappy": ["Why is everyone blocking the way?","The vibe is slipping.","I expected a better night.","Is there even a way to the bar?","Too much waiting, not enough dancing.","I might call it a night.","This place needs some work.","I paid for this?","I can't find a quiet corner.","Maybe the next club is better."],
	"dancing": ["Four to the floor, no thoughts.","This loop has me hypnotized.","Don't touch that filter yet.","That hi-hat is doing things.","I live for this exact moment.","The sub is shaking my ribs.","Another sixteen bars, please.","That transition was filthy.","Deep in the pocket right now.","I can feel the groove in my teeth."],
	"neutral": ["Wonder who's on after this.","Nice crowd tonight.","I should check out the other room.","Did I lock my bike?","This place has potential.","Where did my friends disappear?","Interesting sound system.","I like the lighting in here.","One more tune before deciding.","This feels properly underground."]
}
var guests: Array[Dictionary] = []
var selected_guest_node: Node3D
var guest_info_panel: PanelContainer
var guest_info_label: Label
var guest_thought := ""
var guest_thought_clock := 0.0
var guest_spawn_clock := 0.0
var guest_count := 0
var night_mood_total := 0.0
var night_mood_samples := 0
var night_mood_last := 100.0
var mood_update_clock := 0.0
const NIGHT_DURATION := 240.0  # Four in-game hours; one game hour = 60 simulation seconds.
var ticket_price := 15
var drink_price := 7
var ticket_value_label: Label
var drink_value_label: Label
var ticket_slider: HSlider
var drink_slider: HSlider
var dj_card_title: Label
var dj_card_status: Label
var dj_player: AudioStreamPlayer
var dj_track_paths: Array[String] = []
var dj_track_index := -1
const STAFF_COST := 120
var night_elapsed := 0.0
var night_speed := 1.0
var night_paused := false
var night_ticket_income := 0
var night_drink_income := 0
var night_dj_fee := 0
var night_drinks_sold := 0
var night_bar_missed := 0
var night_bar_clock := 0.0
var bar_service_clocks: Dictionary = {}
var night_bar_queue_peak := 0
var night_wc_queue_peak := 0
var night_wc_visits := 0
var night_wc_waits := 0
var night_operating_cost := 0
var night_supply_cost := 0
var night_capacity_peak := 0
var night_guests_left := 0
var night_unhappy_departures := 0
var night_time_label: Label
var night_speed_button: Button
var night_pause_button: Button
var night_report_panel: PanelContainer
var night_report_heading: Label
var night_report_details: Label
const MAX_GUESTS := 48

func _milestone_achieved(id: String, profit: int) -> bool:
	match id:
		"first_profit":
			return profit > 0
		"full_house":
			return night_capacity_peak >= 40
		"drinks_30":
			return night_drinks_sold >= 30
		"profit_streak":
			return profitable_night_streak >= 3
	return false


func _award_night_milestones(profit: int) -> String:
	profitable_night_streak = profitable_night_streak + 1 if profit > 0 else 0
	var awards: Array[String] = []
	for milestone in CLUB_MILESTONES:
		var id := str(milestone["id"])
		if completed_milestones.has(id) or not _milestone_achieved(id, profit):
			continue
		completed_milestones.append(id)
		var reward := int(milestone["reward"])
		cash += reward
		_award_xp(35)
		awards.append("%s +€%d +35 XP" % [str(milestone["name"]), reward])
	return "  |  ".join(awards)


func _dj_crowd_bonus() -> float:
	if dj_picker == null or dj_picker.selected < 0:
		return 1.0
	var fee := int(DJ_ROSTER[dj_picker.selected]["fee"])
	# More established acts draw a crowd, but do not guarantee profit.
	return 1.0 + clampf(float(fee - 100) / 300.0 * 0.30, 0.0, 0.30)


func _xp_needed(level: int) -> int:
	return 210 + (level - 1) * 85 + (level - 1) * (level - 1) * 10

func _award_xp(amount: int) -> int:
	var gained_levels := 0
	club_xp += maxi(0, amount)
	total_xp += maxi(0, amount)
	while club_xp >= _xp_needed(club_level):
		club_xp -= _xp_needed(club_level)
		club_level += 1
		perk_points += 1
		gained_levels += 1
	return gained_levels

const GUEST_CHARACTER_NAMES := ["baggy_m", "fashion_f", "jungle_f", "raver_f", "raver_m"]
var guest_models: Dictionary = {}
var dj_character_variants: Dictionary = {}
var dj_performers: Array[Dictionary] = []
var dj_animation_clock := 0.0

const GUEST_ENTRY := Vector2i(7, 14)
const WALK_DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const DJ_ROSTER := [
	{"name": "Vanya Velin", "fee": 400},
	{"name": "Velvet 37", "fee": 300},
	{"name": "rozzo", "fee": 350, "bpm": 125.0},
	{"name": "lowQ", "fee": 250},
	{"name": "Basement Resident", "fee": 100}
]

func _ready() -> void:
	_build_world()
	_load_guest_models()
	_load_dj_character_models()
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

const MODEL_TYPES := ["wall", "poster", "dj", "bar", "sofa", "speaker", "light", "laser", "plant2", "table", "stool", "wc", "entrance", "floor", "rail"]
var models: Dictionary = {}
var club_name := "ABLETON GYM"
var club_name_edit: LineEdit
var entrance_sign: Label3D
var poster_labels: Array[Label3D] = []
var poster_led_materials: Array[StandardMaterial3D] = []
var poster_led_lights: Array[OmniLight3D] = []
var poster_led_accents: Array[StandardMaterial3D] = []
var poster_led_clock := 0.0
var club: Node3D
var missing_models: Array[String] = []
var club_environment: Environment
var club_sun: DirectionalLight3D
var stage_lights: Array[SpotLight3D] = []
var lighting_clock := 0.0
var music_beat_clock := 0.0
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
		elif x == SIZE - 1 or x == grid_width - 1:
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
		elif y == SIZE - 1:
			pivot_node.rotation.y = PI
	if not models.has(kind):
		var color: Color = Color("#5d456a") if kind in TWO_CELL else Color("#53505b")
		_make_box(pivot_node, Vector3(0, 0.4, 0.5 if kind in TWO_CELL else 0.0),
			Vector3(0.8, 0.8, 1.8 if kind in TWO_CELL else 0.8), color)
		if kind == "poster":
			_attach_poster_text(pivot_node)
		elif kind == "entrance":
			_attach_entrance_sign(pivot_node)
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
	if kind == "floor" and parent == club:
		floor_heights[Vector2i(x, y)] = _visual_bounds(pivot_node).end.y
	# Sign geometry must be added AFTER fitting the GLB, or it distorts its bounds.
	if kind == "poster":
		_attach_poster_text(pivot_node)
	elif kind == "entrance":
		_attach_entrance_sign(pivot_node)
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
		economy_label.text = "CASH  €%d     REP  %d/100     LEVEL  %d  |  XP %d/%d" % [cash, reputation, club_level, club_xp, _xp_needed(club_level)]
	_refresh_progression()

func _count_kind(kind: String) -> int:
	var count := 0
	for record in placed_objects.values():
		if record["kind"] == kind:
			count += 1
	return count

func _club_capacity() -> int:
	# Dance area is the primary capacity constraint; restrooms limit safe occupancy.
	return mini(dance_tiles.size() * 3, _count_kind("wc") * 48)


func _night_utilities() -> int:
	return 10 + _count_kind("speaker") * 2 + _count_kind("light") * 3 + _count_kind("laser") * 5 + _count_kind("bar") * 3 + _count_kind("wc") * 3


func _night_staff_cost() -> int:
	return STAFF_COST + maxi(0, _count_kind("bar") - 1) * 8 + maxi(0, _count_kind("wc") - 1) * 8


func _night_total_expenses() -> int:
	return night_dj_fee + night_operating_cost + night_supply_cost


func _night_advice() -> String:
	if night_ticket_income + night_drink_income < _night_total_expenses():
		return "LOSS: try a cheaper resident DJ, adjust ticket price or grow attendance."
	if night_bar_queue_peak >= 5 and night_bar_missed > 0:
		return "BAR QUEUES: add a bar or improve access to existing bars."
	if night_wc_waits >= 5:
		return "WC QUEUES: add another restroom or clear its approaches."
	if night_bar_missed >= 3 and _count_kind("bar") < 2:
		return "BAR BOTTLENECK: add a bar to serve more guests."
	if night_capacity_peak >= _club_capacity() and _club_capacity() < MAX_GUESTS:
		return "CAPACITY LIMIT: expand dance floor / restrooms."
	if _count_kind("speaker") < 3:
		return "SOUND: an extra speaker can improve guest mood."
	if _count_kind("sofa") == 0:
		return "COMFORT: sofas help tired guests stay happy."
	return "Keep improving the layout and monitoring guest mood."


func _readiness_issues() -> Array[String]:
	var issues: Array[String] = []
	if dance_tiles.size() < 6:
		issues.append("6 dance tiles")
	if _count_kind("dj") < 1:
		issues.append("DJ booth")
	if _count_kind("speaker") < 2:
		issues.append("2 speakers")
	if _count_kind("bar") < 1:
		issues.append("bar")
	if _count_kind("wc") < 1:
		issues.append("restroom")
	if dj_picker != null and dj_picker.selected >= 0:
		var fee := _dj_fee(dj_picker.selected)
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
	return cell.x > 0 and cell.x < grid_width - 1 and cell.y > 0 and cell.y < SIZE - 1 and not occupied.has(cell)

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

func _make_dance_tile(cell: Vector2i, parent: Node3D) -> Node3D:
	# Reuse the imported floor.glb and the existing grid model fitting.
	# _model also updates floor_heights from the actual visible mesh top.
	return _model(parent, "floor", cell.x, cell.y)


func _add_dance_tile(cell: Vector2i, paid: bool = false) -> void:
	if dance_tiles.has(cell):
		return
	dance_tiles[cell] = {"node": _make_dance_tile(cell, club), "paid": paid}
	floor_heights[cell] = _visual_bounds(dance_tiles[cell]["node"]).end.y


func _remove_dance_tile(cell: Vector2i) -> Dictionary:
	if not dance_tiles.has(cell):
		return {}
	var record: Dictionary = dance_tiles[cell]
	var node := record["node"] as Node3D
	if is_instance_valid(node):
		node.queue_free()
	dance_tiles.erase(cell)
	floor_heights[cell] = -0.005
	return {"paid": bool(record.get("paid", false))}


func _clear_dance_tiles() -> void:
	for cell in dance_tiles.keys().duplicate():
		_remove_dance_tile(cell)


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
		var candidates: Array = dance_tiles.keys()
		if candidates.is_empty():
			return Vector2i(-1, -1)
		var candidate: Vector2i = candidates.pick_random()
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

func _load_dj_character_models() -> void:
	dj_character_variants.clear()
	for motion in ["idle", "standing", "handdsup"]:
		var path := "res://characters/deejay_%s.glb" % motion
		if ResourceLoader.exists(path):
			var packed := load(path) as PackedScene
			if packed != null:
				dj_character_variants[motion] = packed


func _clear_dj_performers() -> void:
	for performer in dj_performers:
		var anchor := performer.get("anchor") as Node3D
		if is_instance_valid(anchor):
			anchor.queue_free()
	dj_performers.clear()


func _show_dj_motion(performer: Dictionary, motion: String) -> void:
	var variants: Dictionary = performer["variants"]
	for key in variants:
		var visual := variants[key] as Node3D
		if is_instance_valid(visual):
			visual.visible = key == motion


func _spawn_dj_performers() -> void:
	_clear_dj_performers()
	if dj_character_variants.is_empty():
		return
	for record in placed_objects.values():
		if str(record["kind"]) != "dj":
			continue
		var booth := record["node"] as Node3D
		if not is_instance_valid(booth):
			continue
		# The booth pivot carries its 90-degree rotation. +Z is the operator
		# side (below the decks in the default isometric view).
		var anchor := Node3D.new()
		anchor.name = "PerformingDJ"
		booth.add_child(anchor)
		anchor.position = Vector3(-0.98, 0.0, 0.0)
		anchor.rotation.y = PI * 0.5
		var variants: Dictionary = {}
		for motion in ["idle", "standing", "handdsup"]:
			if not dj_character_variants.has(motion):
				continue
			var visual := _guest_animated_model(dj_character_variants[motion], anchor)
			if visual != null:
				variants[motion] = visual
		if variants.is_empty():
			anchor.queue_free()
			continue
		var performer := {"anchor": anchor, "variants": variants}
		dj_performers.append(performer)
		_show_dj_motion(performer, "idle" if variants.has("idle") else str(variants.keys()[0]))


func _animate_dj_performers(step: float) -> void:
	if dj_performers.is_empty():
		return
	dj_animation_clock += step
	var phase := fmod(dj_animation_clock, 18.0)
	for performer in dj_performers:
		var variants: Dictionary = performer["variants"]
		var motion := "handdsup" if phase > 14.0 else ("standing" if phase > 9.0 else "idle")
		if not variants.has(motion):
			motion = "idle" if variants.has("idle") else str(variants.keys()[0])
		_show_dj_motion(performer, motion)


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

const RAVER_FIRST_NAMES_M := ["Bass", "Duke", "Felix", "Milo", "Ricky", "Jasper", "Theo", "Otto", "Benny", "Lenny", "Max", "Arlo", "Dimitri", "Vinyl", "Klaus", "Nico", "Pablo", "Dizzy", "Boris", "Rufus", "Percy", "Remy", "Dexter", "Lars"]
const RAVER_FIRST_NAMES_F := ["Lola", "Mimi", "Nina", "Roxy", "Luna", "Kiki", "Zelda", "Greta", "Fifi", "Maya", "Juno", "Trixie", "Daisy", "Cleo", "Polly", "Sasha", "Mona", "Rita", "Ivy", "Frida", "Pixie", "Bea", "Nova", "Vera"]
const RAVER_LAST_NAMES := ["Kickdrum", "Van Bass", "McGroove", "Breakbeat", "Hi-Hat", "Fourfour", "Dubplate", "Sidechain", "Lowpass", "Subwoofer", "Afterhours", "Reverb", "Wobble", "Vinylson", "Snarewell", "De Rave", "Bassington", "Acidberg", "Beatnik", "Fader", "Loopinski", "Technov", "Shuffleton", "Amen", "Oscillator", "Boombox", "Del Delay", "Rumbles", "808", "Backspin", "Kicks", "Detune"]


func _generate_raver_name(character: String) -> String:
	var first_names: Array = RAVER_FIRST_NAMES_F if character.ends_with("_f") else RAVER_FIRST_NAMES_M
	return str(first_names.pick_random()) + " " + str(RAVER_LAST_NAMES.pick_random())


func _spawn_guest() -> bool:
	if guests.size() >= MAX_GUESTS or not _walkable(GUEST_ENTRY) or _guest_too_close(_cell_position(GUEST_ENTRY), {}):
		return false
	var destination := _dance_destination()
	if destination.x < 0:
		return false
	var path := _path_to(GUEST_ENTRY, destination)
	if path.is_empty():
		return false
	var person := Node3D.new()
	guest_layer.add_child(person)
	person.position = _cell_position(GUEST_ENTRY)
	var appearance := _guest_visual(person)
	guests.append({"node": person, "visual": appearance["visual"], "arms": appearance["arms"], "legs": appearance["legs"], "imported": appearance["imported"], "motions": appearance["motions"], "motion": "walk", "character": appearance.get("character", ""), "full_name": _generate_raver_name(str(appearance.get("character", ""))), "path": path, "dance": false, "phase": randf() * TAU, "speed": randf_range(1.25, 1.85), "state": "walk_dance", "cell": GUEST_ENTRY, "wait": randf_range(8.0, 16.0), "visits": 0, "wallet": randi_range(18, 60), "thirst": randf_range(0.25, 0.65), "wc_need": randf_range(0.0, 0.35), "mood": 85.0, "energy": randf_range(0.65, 1.0), "destination": destination, "service_object": -1, "blocked_time": 0.0, "repath_cooldown": 0.0, "time_inside": 0.0, "leaving": false})
	guest_count += 1
	night_ticket_income += ticket_price
	cash += ticket_price
	_update_night_stats()
	_refresh_economy()
	_refresh_readiness()
	return true

func _service_queue_size(kind: String, object_id: int) -> int:
	var count := 0
	for other in guests:
		if int(other.get("service_object", -1)) != object_id:
			continue
		var state := str(other.get("state", ""))
		if kind == "bar" and state in ["walk_bar", "ordering"]:
			count += 1
		elif kind == "wc" and state in ["walk_wc", "using_wc"]:
			count += 1
	return count


func _update_service_queues() -> void:
	var bar_peak := 0
	var wc_peak := 0
	for record_id in placed_objects:
		var kind := str(placed_objects[record_id]["kind"])
		if kind == "bar":
			bar_peak = maxi(bar_peak, _service_queue_size("bar", int(record_id)))
		elif kind == "wc":
			wc_peak = maxi(wc_peak, _service_queue_size("wc", int(record_id)))
	night_bar_queue_peak = maxi(night_bar_queue_peak, bar_peak)
	night_wc_queue_peak = maxi(night_wc_queue_peak, wc_peak)


func _service_destination(kind: String, start: Vector2i, guest: Dictionary) -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_object := -1
	var best_score := INF
	for object_id in placed_objects:
		var record: Dictionary = placed_objects[object_id]
		if str(record["kind"]) != kind:
			continue
		var queue_size := _service_queue_size(kind, int(object_id))
		if kind == "bar" and queue_size >= 5:
			continue
		if kind == "wc" and queue_size >= 4:
			continue
		if kind == "sofa":
			var reserved := false
			for other in guests:
				if other != guest and int(other.get("service_object", -1)) == int(object_id):
					reserved = true
					break
			if reserved:
				continue
		for furniture_cell in record["cells"]:
			for direction in WALK_DIRS:
				var candidate: Vector2i = furniture_cell + direction
				if not _walkable(candidate) or _destination_taken(candidate, guest):
					continue
				var path := _path_to(start, candidate)
				if candidate != start and path.is_empty():
					continue
				# A short walk matters, but a crowded service point is slower.
				# Different adjacent cells form natural waiting positions.
				var queue_penalty := 0.0
				if kind == "bar":
					queue_penalty = float(queue_size) * 5.0
				elif kind == "wc":
					queue_penalty = float(queue_size) * 3.0
				var score := float(path.size()) + queue_penalty
				if score < best_score:
					best = candidate
					best_object = int(object_id)
					best_score = score
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

func _face_service_object(guest: Dictionary) -> void:
	var object_id := int(guest.get("service_object", -1))
	if not placed_objects.has(object_id):
		return
	var target_node := placed_objects[object_id]["node"] as Node3D
	var person := guest["node"] as Node3D
	if not is_instance_valid(target_node) or not is_instance_valid(person):
		return
	var toward := target_node.global_position - person.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.001:
		person.rotation.y = atan2(toward.x, toward.z)


func _guest_arrived(guest: Dictionary) -> void:
	var state: String = guest["state"]
	if state == "walk_exit":
		guest["leaving"] = true
		return
	if state == "walk_bar":
		guest["state"] = "ordering"
		guest["wait"] = randf_range(2.0, 4.0)
		_face_service_object(guest)
	elif state == "walk_wc":
		guest["state"] = "using_wc"
		guest["wait"] = 1.0
		guest["wc_need"] = 0.0
		guest["visual"].visible = false
		_face_service_object(guest)
		night_wc_visits += 1
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

func _guest_mood(guest: Dictionary) -> float:
	var thirst_penalty := maxf(0.0, float(guest["thirst"]) - 0.35) * 65.0
	var fatigue_penalty := maxf(0.0, 0.55 - float(guest["energy"])) * 65.0
	var waiting_penalty := minf(22.0, float(guest.get("blocked_time", 0.0)) * 1.4 + float(guest.get("bar_waited", 0.0)) * 0.8)
	var service_penalty := 0.0
	if float(guest["thirst"]) > 0.65 and _count_kind("bar") == 0:
		service_penalty += 22.0
	if float(guest["energy"]) < 0.35 and _count_kind("sofa") == 0:
		service_penalty += 12.0
	var wc_penalty := maxf(0.0, float(guest.get("wc_need", 0.0)) - 0.75) * 65.0
	var dancing_bonus := 9.0 if bool(guest["dance"]) else 0.0
	var sound_bonus := minf(6.0, float(maxi(0, _count_kind("speaker") - 2)) * 2.0)
	var atmosphere_bonus := minf(8.0, float(_count_kind("light")) * 2.0 + float(_count_kind("laser")) * 3.0 + float(_count_kind("plant2")) * 0.5)
	var comfort_bonus := minf(4.0, float(_count_kind("table") + _count_kind("stool")) * 0.7)
	return clampf(86.0 + dancing_bonus + sound_bonus + atmosphere_bonus + comfort_bonus - thirst_penalty - fatigue_penalty - waiting_penalty - service_penalty - wc_penalty, 0.0, 100.0)


func _average_guest_mood() -> float:
	if guests.is_empty():
		return night_mood_last
	var total := 0.0
	for guest in guests:
		total += float(guest.get("mood", 85.0))
	return total / float(guests.size())


func _guest_thought_category(guest: Dictionary) -> String:
	if float(guest["thirst"]) > 0.68:
		return "thirst"
	if float(guest["energy"]) < 0.35:
		return "tired"
	if float(guest.get("mood", 85.0)) < 55.0:
		return "unhappy"
	if bool(guest.get("dance", false)):
		return "dancing" if randf() < 0.65 else "happy"
	if float(guest.get("mood", 85.0)) > 83.0:
		return "happy"
	return "neutral"


func _refresh_guest_info(delta: float) -> void:
	if guest_info_panel == null or selected_guest_node == null or not is_instance_valid(selected_guest_node):
		if guest_info_panel != null:
			guest_info_panel.hide()
		return
	for guest in guests:
		if guest["node"] != selected_guest_node:
			continue
		guest_info_panel.show()
		guest_thought_clock -= delta
		if guest_thought_clock <= 0.0:
			var category := _guest_thought_category(guest)
			guest_thought = str(RAVER_THOUGHTS[category].pick_random())
			guest_thought_clock = randf_range(6.0, 11.0)
		var activity := str(guest.get("state", "dancing")).replace("_", " ").capitalize()
		guest_info_label.text = "%s  |  %s\nMOOD       %d%%\nTHIRST      %d%%\nENERGY     %d%%\n\n“%s”" % [str(guest.get("full_name", "Raver")), activity, roundi(float(guest.get("mood", 85.0))), roundi(float(guest["thirst"]) * 100.0), roundi(float(guest["energy"]) * 100.0), guest_thought]
		return
	guest_info_panel.hide()


func _select_guest_at(screen_pos: Vector2) -> bool:
	var closest := 32.0
	var found: Node3D = null
	for guest in guests:
		var person := guest["node"] as Node3D
		if not is_instance_valid(person) or camera.is_position_behind(person.global_position + Vector3.UP * 0.7):
			continue
		var screen := camera.unproject_position(person.global_position + Vector3.UP * 0.7)
		var distance := screen.distance_to(screen_pos)
		if distance < closest:
			closest = distance
			found = person
	if found == null:
		selected_guest_node = null
		if guest_info_panel != null:
			guest_info_panel.hide()
		return false
	selected_guest_node = found
	guest_thought_clock = 0.0
	_refresh_guest_info(0.0)
	return true


func _process(delta: float) -> void:
	if night_active:
		_refresh_guest_info(delta)
	_animate_poster_leds(delta)
	_animate_stage_lights(delta)
	if not night_active or night_paused:
		return
	var step := delta * night_speed
	_animate_dj_performers(step)
	night_elapsed += step
	if night_elapsed >= NIGHT_DURATION:
		_end_night()
		return
	if night_time_label != null:
		var remaining := ceili(NIGHT_DURATION - night_elapsed)
		night_time_label.text = "TIME LEFT  %d:%02d  |  €%d TICKETS  €%d BAR" % [int(remaining / 60.0), remaining % 60, night_ticket_income, night_drink_income]
	mood_update_clock += step
	if mood_update_clock >= 1.0:
		mood_update_clock = 0.0
		if not guests.is_empty():
			night_mood_last = _average_guest_mood()
			night_mood_total += night_mood_last
			night_mood_samples += 1
		_update_night_stats()
	guest_spawn_clock += step
	night_bar_clock += step
	for record_id in placed_objects:
		if str(placed_objects[record_id]["kind"]) == "bar":
			bar_service_clocks[record_id] = float(bar_service_clocks.get(record_id, 5.0)) + step
	_update_service_queues()
	night_capacity_peak = maxi(night_capacity_peak, guests.size())
	if guest_spawn_clock >= clampf((4.0 + float(ticket_price - 5) * 0.16 - float(club_level - 1) * 0.12 - float(reputation - 50) * 0.018) / (_dj_crowd_bonus() * (1.0 + (0.08 if unlocked_perks.has("lineups") else 0.0) + (0.05 if unlocked_perks.has("word") else 0.0) + (0.10 if unlocked_perks.has("regulars") else 0.0))), 1.8, 6.0) and guests.size() < _club_capacity():
		if _spawn_guest():
			guest_spawn_clock = 0.0
		else:
			# Keep the arrival ready if the entrance is briefly blocked.
			guest_spawn_clock = 2.0
	for guest in guests:
		# Guest needs evolve during the night and influence where they go.
		guest["time_inside"] = float(guest.get("time_inside", 0.0)) + step
		if str(guest.get("state", "")) != "walk_exit" and not bool(guest.get("leaving", false)):
			var exhausted := float(guest["energy"]) < 0.16
			var unhappy := float(guest.get("mood", 85.0)) < 35.0 and float(guest["time_inside"]) > 30.0
			var finished := float(guest["time_inside"]) > 110.0 + float(guest["energy"]) * 60.0
			if exhausted or unhappy or finished:
				var exit_path := _path_to(guest["cell"], GUEST_ENTRY)
				if not exit_path.is_empty():
					guest["path"] = exit_path
					guest["destination"] = GUEST_ENTRY
					guest["service_object"] = -1
					guest["state"] = "walk_exit"
					guest["dance"] = false
					if unhappy:
						night_unhappy_departures += 1
		guest["thirst"] = minf(1.0, float(guest["thirst"]) + step * (0.0025 if bool(guest["dance"]) else 0.001))
		guest["energy"] = maxf(0.0, float(guest["energy"]) - step * (0.0018 if bool(guest["dance"]) else 0.0005))
		guest["wc_need"] = minf(1.0, float(guest.get("wc_need", 0.0)) + step * 0.002 + (step * 0.0005 if bool(guest["dance"]) else 0.0))
		guest["mood"] = _guest_mood(guest)
		var state: String = guest["state"]
		if state in ["dancing", "ordering", "resting", "sitting", "standing", "using_wc"]:
			guest["wait"] = float(guest["wait"]) - step
			if float(guest["wait"]) <= 0.0:
				if state == "using_wc":
					guest["visual"].visible = true
					guest["wc_need"] = 0.0
					if not _guest_route(guest, "dance"):
						guest["state"] = "dancing"
						guest["dance"] = true
						guest["wait"] = 5.0
				elif state == "sitting":
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
					var wants_to_buy := float(guest["thirst"]) >= 0.35 and int(guest["wallet"]) >= drink_price
					var bar_id := int(guest.get("service_object", -1))
					var service_interval := 5.0
					if wants_to_buy and bar_id >= 0 and float(bar_service_clocks.get(bar_id, 0.0)) >= service_interval:
						bar_service_clocks[bar_id] = 0.0
						night_drinks_sold += 1
						night_supply_cost += 2
						var sale := roundi(float(drink_price) * (1.0 + (0.05 if unlocked_perks.has("happy") else 0.0) + (0.10 if unlocked_perks.has("premium") else 0.0)))
						night_drink_income += sale
						cash += sale
						guest["wallet"] = int(guest["wallet"]) - drink_price
						guest["thirst"] = maxf(0.0, float(guest["thirst"]) - 0.65)
						guest["wc_need"] = minf(1.0, float(guest["wc_need"]) + 0.22)
						_update_night_stats()
						_refresh_economy()
					elif wants_to_buy and float(guest.get("bar_waited", 0.0)) < 12.0:
						guest["bar_waited"] = float(guest.get("bar_waited", 0.0)) + 2.0
						guest["wait"] = 2.0
						continue
					elif wants_to_buy:
						night_bar_missed += 1
					guest["bar_waited"] = 0.0
					guest["visits"] = int(guest["visits"]) + 1
					if not _guest_route(guest, "dance"):
						guest["wait"] = 4.0
				elif state == "resting":
					if not _guest_route(guest, "dance"):
						guest["wait"] = 4.0
				else:
					var wants_wc := float(guest.get("wc_need", 0.0)) > 0.7
					if wants_wc and _guest_route(guest, "wc"):
						continue
					if wants_wc:
						night_wc_waits += 1
						guest["wait"] = 2.0
						continue
					var wants_drink := float(guest["thirst"]) > (0.48 + maxf(0.0, float(drink_price - 7)) * 0.018) and int(guest["wallet"]) >= drink_price
					var wants_rest := float(guest["energy"]) < 0.45
					var activity := "bar" if wants_drink else "sofa" if wants_rest else ("bar" if randf() < 0.3 and int(guest["wallet"]) >= drink_price else "sofa")
					if not _guest_route(guest, activity):
						if not _guest_route(guest, "sofa" if activity == "bar" else "dance"):
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
		if str(guest["state"]) in ["ordering", "resting", "sitting", "standing", "using_wc"]:
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

	# Remove guests only after iteration so service reservations and paths remain stable.
	for index in range(guests.size() - 1, -1, -1):
		if bool(guests[index].get("leaving", false)):
			var departing: Node3D = guests[index]["node"]
			if selected_guest_node == departing:
				selected_guest_node = null
			if is_instance_valid(departing):
				departing.queue_free()
			guests.remove_at(index)
			night_guests_left += 1

func _clear_guests() -> void:
	selected_guest_node = null
	if guest_info_panel != null:
		guest_info_panel.hide()
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
	spot.light_volumetric_fog_energy = 7.0 if kind == "light" else 0.0
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
	beam.visible = night_active and kind == "laser"
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
			# Moving heads use volumetric fog; only lasers have visible geometry.
			beam.visible = enabled and beam.get_node_or_null("LaserHalo") != null
	for glow in dance_lights:
		if is_instance_valid(glow):
			glow.light_energy = 1.2 if enabled else 0.0
	if enabled:
		_debug_fixture_lights()

func _animate_stage_lights(delta: float) -> void:
	if not night_active or night_paused:
		return
	lighting_clock += delta * night_speed
	var synced_beat := _rozzo_beat()
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
		spot.light_energy = (2.5 + 4.0 * synced_beat) if synced_beat >= 0.0 else 3.0 + 2.0 * (0.5 + 0.5 * sin(lighting_clock * 3.0 + float(index)))
	# Independent color changes and a restrained rhythmic flash for moving heads.
	for index in range(disco_spots.size()):
		var disco := disco_spots[index]
		if not is_instance_valid(disco):
			continue
		var palette_index := (int(floor(lighting_clock / 5.0)) + index * 2) % DISCO_COLORS.size()
		var color: Color = DISCO_COLORS[palette_index]
		disco.light_color = color
		var beat := synced_beat if synced_beat >= 0.0 else pow(maxf(0.0, sin(lighting_clock * 4.0 + float(index) * 1.7)), 8.0)
		disco.light_energy = 3.6 + 2.3 * beat
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
	var fee := _dj_fee(dj_picker.selected)
	cash -= fee
	night_dj_fee = fee
	night_elapsed = 0.0
	night_mood_total = 0.0
	night_mood_samples = 0
	night_mood_last = 100.0
	mood_update_clock = 0.0
	music_beat_clock = 0.0
	poster_led_clock = 0.0
	night_paused = false
	night_speed = 1.0
	night_ticket_income = 0
	night_drink_income = 0
	night_drinks_sold = 0
	night_bar_missed = 0
	night_bar_clock = 0.0
	bar_service_clocks.clear()
	night_bar_queue_peak = 0
	night_wc_queue_peak = 0
	night_wc_visits = 0
	night_wc_waits = 0
	night_supply_cost = 0
	night_operating_cost = _night_staff_cost() + _night_utilities()
	night_capacity_peak = 0
	night_guests_left = 0
	night_unhappy_departures = 0
	if night_report_panel != null:
		night_report_panel.show()
	_update_night_stats()
	night_number += 1
	night_active = true
	_refresh_poster_text()
	_refresh_club_sign()
	_set_night_lighting(true)
	dj_animation_clock = 0.0
	_spawn_dj_performers()
	_play_dj_music()
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
	ticket_slider.editable = false
	drink_slider.editable = false
	night_pause_button.disabled = false
	night_speed_button.disabled = false
	night_pause_button.text = "PAUSE"
	night_speed_button.text = "1× SPEED"
	night_time_label.text = "TIME LEFT  4:00  |  €0 TICKETS  €0 BAR"

func _end_night() -> void:
	if not night_active:
		return
	night_active = false
	_refresh_poster_text()
	_refresh_club_sign()
	_set_night_lighting(false)
	_clear_dj_performers()
	_stop_dj_music()
	var costs := _night_total_expenses()
	cash -= night_operating_cost + night_supply_cost
	# Reputation reflects turnout, bar service and the night's finances.
	var revenue := night_ticket_income + night_drink_income
	var profit := revenue - costs
	var turnout_score := clampf(float(guest_count) / 32.0, 0.0, 1.0)
	var service_score := float(night_drinks_sold) / float(maxi(1, guest_count))
	var average_mood := night_mood_total / float(night_mood_samples) if night_mood_samples > 0 else night_mood_last
	var price_pressure := maxf(0.0, float(ticket_price - 20)) * 0.14 + maxf(0.0, float(drink_price - 10)) * 0.18
	var reputation_delta := roundi((turnout_score - 0.45) * 5.0 + (service_score - 0.3) * 4.0 + (average_mood - 65.0) * 0.12 + (2.0 if profit > 0 else -3.0) - price_pressure - float(night_unhappy_departures) * 0.5)
	last_rep_change = clampi(reputation_delta, -7, 7)
	reputation = clampi(reputation + last_rep_change, 0, 100)
	last_xp_gain = maxi(10, roundi(float(guest_count) * 2.0 + float(night_drinks_sold) * 1.2 + average_mood * 0.22 + (12.0 if profit > 0 else 0.0)))
	var levels_gained := _award_xp(last_xp_gain)
	var milestone_awards := _award_night_milestones(profit)
	_clear_guests()
	_refresh_economy()
	night_pause_button.disabled = true
	night_speed_button.disabled = true
	night_time_label.text = "NIGHT COMPLETE"
	_update_night_stats()
	start_night_button.text = "START NIGHT"
	ticket_slider.editable = true
	drink_slider.editable = true
	_refresh_readiness()
	_notify("Night %d ended  |  %d guests visited  |  Profit %s€%d  |  XP +%d  |  REP %+d%s" % [night_number, guest_count, "+" if profit >= 0 else "-", absi(profit), last_xp_gain, last_rep_change, "  |  LEVEL UP!" if levels_gained > 0 else ""])
	if not milestone_awards.is_empty():
		_notify("MILESTONES  |  " + milestone_awards)

func _update_night_stats() -> void:
	if night_report_details == null:
		return
	var revenue := night_ticket_income + night_drink_income
	var expenses := _night_total_expenses()
	var profit := revenue - expenses
	var mood := _average_guest_mood() if night_active else (night_mood_total / float(night_mood_samples) if night_mood_samples > 0 else night_mood_last)
	night_report_heading.text = "NIGHT %d  |  %s" % [night_number, "LIVE STATS" if night_active else "REPORT"]
	var break_even := maxi(0, expenses - night_drink_income)
	var tickets_needed := ceili(float(break_even) / float(maxi(1, ticket_price)))
	var lines: Array[String] = [
		"MOOD  %d%%     GUESTS  %d" % [roundi(mood), guest_count],
		"CAPACITY  %d     PEAK  %d" % [_club_capacity(), night_capacity_peak],
		"GUESTS LEFT  %d     UNHAPPY  %d" % [night_guests_left, night_unhappy_departures],
		"VISIBLE GUEST LIMIT  %d" % MAX_GUESTS,
		"DANCE TILES  %d     BARS  %d" % [dance_tiles.size(), _count_kind("bar")],
		"DRINKS SOLD  %d     MISSED  %d" % [night_drinks_sold, night_bar_missed],
		"WC VISITS  %d     WC WAITS  %d" % [night_wc_visits, night_wc_waits],
		"BAR QUEUE PEAK  %d     WC QUEUE PEAK  %d" % [night_bar_queue_peak, night_wc_queue_peak],
		"",
		"TICKETS                 +€%d" % night_ticket_income,
		"BAR SALES              +€%d" % night_drink_income,
		"TOTAL REVENUE      €%d" % revenue,
		"DJ BOOKING           -€%d" % night_dj_fee,
		"STAFF + UTILITIES   -€%d" % night_operating_cost,
		"DRINK SUPPLIES      -€%d" % night_supply_cost,
		"NET PROFIT            %s€%d" % ["+" if profit >= 0 else "-", absi(profit)],
		"BREAK-EVEN TICKETS  %d at €%d" % [tickets_needed, ticket_price],
		"",
		"LEVEL %d  XP %d/%d" % [club_level, club_xp, _xp_needed(club_level)],
		"REPUTATION %d/100" % reputation
	]
	if not night_active:
		lines.append("NIGHT XP +%d    REP %+d" % [last_xp_gain, last_rep_change])
		lines.append("")
		lines.append(_night_advice())
		lines.append("")
		lines.append("CLUB MILESTONES  %d/%d" % [completed_milestones.size(), CLUB_MILESTONES.size()])
		for milestone in CLUB_MILESTONES:
			lines.append("%s  %s  +€%d" % ["✓" if completed_milestones.has(str(milestone["id"])) else "○", str(milestone["name"]), int(milestone["reward"])])
	night_report_details.text = "\n".join(lines)

func _build_price(kind: String) -> int:
	var base := int(BUILD_PRICES.get(kind, 0))
	# Essentials retain their affordable price. Later unlocks cost more
	# because they are premium additions, not because the player leveled up.
	return base


func _refresh_build_catalog() -> void:
	for kind in catalog_buttons:
		var button := catalog_buttons[kind] as Button
		if not is_instance_valid(button):
			continue
		var required_level := int(LEVEL_UNLOCKS.get(kind, 1))
		var locked := club_level < required_level
		var label := str(BUILD_NAMES.get(kind, kind.capitalize()))
		var price := _build_price(kind)
		button.text = "🔒 %s  ·  LVL %d" % [label, required_level] if locked else "%s   €%d" % [label, price]
		button.tooltip_text = "Unlocks at level %d" % required_level if locked else "%s · €%d" % [label, price]
		button.disabled = locked


func _refresh_prices() -> void:
	_refresh_build_catalog()
	if ticket_value_label != null:
		ticket_value_label.text = "€%d" % ticket_price
	if drink_value_label != null:
		drink_value_label.text = "€%d" % drink_price
	if night_time_label != null and not night_active:
		night_time_label.text = "4-HOUR NIGHT  |  TICKETS €%d  |  DRINKS €%d" % [ticket_price, drink_price]


func _refresh_dj_card() -> void:
	if dj_card_title == null or dj_picker == null or dj_picker.selected < 0:
		return
	var dj_name := str(DJ_ROSTER[dj_picker.selected]["name"])
	dj_card_title.text = "%s  ·  %s" % [dj_name, "DEEP TECH" if dj_name == "rozzo" else "GUEST DJ"]
	if dj_card_status != null:
		dj_card_status.text = "Random local MP3 plays when the night starts." if dj_name == "rozzo" else "Book this DJ to start the night."


func _play_dj_music() -> void:
	if dj_player == null:
		return
	dj_player.stop()
	dj_track_paths.clear()
	dj_track_index = -1
	if dj_picker == null or dj_picker.selected < 0:
		return
	var dj_name := str(DJ_ROSTER[dj_picker.selected]["name"])
	# Place MP3 files in godot/audio/rozzo/; additional DJs can get folders later.
	var folder := "res://audio/rozzo" if dj_name == "rozzo" else ""
	if folder.is_empty():
		_refresh_dj_card()
		return
	var directory := DirAccess.open(folder)
	if directory == null:
		dj_card_status.text = "Add MP3 tracks to godot/audio/rozzo/"
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.get_extension().to_lower() == "mp3":
			dj_track_paths.append(folder.path_join(filename))
		filename = directory.get_next()
	directory.list_dir_end()
	dj_track_paths.shuffle()
	_play_next_dj_track()


func _play_next_dj_track() -> void:
	if not night_active or dj_track_paths.is_empty() or dj_player == null:
		return
	dj_track_index = (dj_track_index + 1) % dj_track_paths.size()
	var path := dj_track_paths[dj_track_index]
	var stream := load(path) as AudioStream
	if stream == null:
		dj_card_status.text = "Cannot play: " + path.get_file()
		return
	dj_player.stream = stream
	dj_player.play()
	if dj_card_status != null:
		dj_card_status.text = "▶  " + path.get_file().get_basename()


func _stop_dj_music() -> void:
	if dj_player != null:
		dj_player.stop()
	_refresh_dj_card()


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
		if str(record["kind"]) == "poster":
			var label := node.find_child("DJPosterText", true, false) as Label3D
			if label != null:
				poster_labels.erase(label)
		node.get_parent().remove_child(node)
		node.queue_free()
	placed_objects.erase(id)
	return {"kind": record["kind"], "x": record["x"], "y": record["y"], "turn": record["turn"], "paid": record.get("paid", false)}

func _erase_hovered() -> void:
	if night_active:
		_notify("Finish the night before editing")
		return
	var id: int = int(object_at_cell.get(hover_cell, -1))
	if id < 0 and dance_tiles.has(hover_cell):
		var removed_tile := _remove_dance_tile(hover_cell)
		var refund := 35 if bool(removed_tile.get("paid", false)) else 0
		cash += refund
		action_history.append({"action": "tile_erase", "cell": hover_cell, "paid": bool(removed_tile.get("paid", false)), "refund": refund})
		_refresh_economy()
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
		return
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
	if action["action"] == "tile_move":
		var destination: Vector2i = action["to"]
		var origin: Vector2i = action["from"]
		if dance_tiles.has(destination) and not dance_tiles.has(origin):
			var paid := bool(dance_tiles[destination].get("paid", false))
			_remove_dance_tile(destination)
			_add_dance_tile(origin, paid)
			moving_dance_tile = origin if moving_dance_tile == destination else moving_dance_tile
	elif action["action"] == "tile_place":
		_remove_dance_tile(action["cell"])
		cash += int(action["cost"])
	elif action["action"] == "tile_erase":
		_add_dance_tile(action["cell"], bool(action["paid"]))
		cash -= int(action["refund"])
	elif action["action"] == "place":
		var removed := _remove_object(int(action["id"]))
		if not removed.is_empty():
			cash += int(action["cost"])
			_notify("Placement undone  |  €%d returned" % int(action["cost"]))
	elif action["action"] == "move":
		var current := _remove_object(int(action["id"]))
		if not current.is_empty():
			var node := _model(club, str(current["kind"]), int(action["x"]), int(action["y"]), int(action["turn"]))
			var restored := _register_object(node, str(current["kind"]), int(action["x"]), int(action["y"]), int(action["turn"]))
			_attach_fixture_lighting(node, str(current["kind"]))
			placed_objects[restored]["paid"] = current["paid"]
			_notify("Move undone")
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
		if kind == "dance_tile" and dance_tiles.has(cell):
			return false
		if cell.x <= 0 or cell.y <= 0 or cell.x >= grid_width - 1 or cell.y >= SIZE - 1 or occupied.has(cell):
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
	if (not build_mode and not object_dragging) or erase_mode or (not build_kind_selected and not object_dragging) or hover_cell.x < 0 or hover_cell.y < 0 or hover_cell.x >= grid_width or hover_cell.y >= SIZE:
		return
	var preview_kind := "dance_tile" if moving_dance_tile.x >= 0 else (str(placed_objects[moving_object_id]["kind"]) if placed_objects.has(moving_object_id) else selected_kind)
	var preview_turn := moving_turn if moving_object_id >= 0 else build_turn
	var node := _make_dance_tile(hover_cell, preview_root) if preview_kind == "dance_tile" else _model(preview_root, preview_kind, hover_cell.x, hover_cell.y, preview_turn)
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		var overlay := StandardMaterial3D.new()
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.albedo_color = Color(0.25, 1.0, 0.6, 0.32) if (_can_move_to(hover_cell.x, hover_cell.y) if moving_object_id >= 0 or moving_dance_tile.x >= 0 else _can_place(hover_cell.x, hover_cell.y, selected_kind, build_turn)) else Color(1.0, 0.2, 0.3, 0.35)
		mesh.material_overlay = overlay

func _update_hover(screen_pos: Vector2) -> void:
	if (build_panel != null and build_panel.visible and build_panel.get_global_rect().has_point(screen_pos)) or (build_toggle != null and build_toggle.get_global_rect().has_point(screen_pos)):
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
	if x < 0 or y < 0 or x >= grid_width or y >= SIZE:
		hover_mesh.visible = false
		preview_root.visible = false
		hover_cell = Vector2i(-1, -1)
		return
	var next_cell := Vector2i(x, y)
	var changed := next_cell != hover_cell
	hover_cell = next_cell
	hover_mesh.visible = (build_mode and (erase_mode or build_kind_selected)) or object_dragging
	preview_root.visible = (build_mode and build_kind_selected) or object_dragging
	hover_mesh.position = Vector3(x - 7.5, float(floor_heights.get(next_cell, 0.0)) + 0.035, y - 7.5)
	var mat := hover_mesh.material_override as StandardMaterial3D
	mat.albedo_color = (Color(1.0, 0.35, 0.2, 0.45) if object_at_cell.has(next_cell) or dance_tiles.has(next_cell) else Color(0.5, 0.5, 0.5, 0.25)) if erase_mode else (Color(0.2, 1.0, 0.55, 0.4) if (_can_move_to(x, y) if moving_object_id >= 0 or moving_dance_tile.x >= 0 else _can_place(x, y, selected_kind, build_turn)) else Color(1.0, 0.25, 0.3, 0.4))
	if changed:
		_refresh_preview()
	_update_rotate_button()

func _update_rotate_button() -> void:
	if rotate_object_button == null:
		return
	var show_button := not night_active and moving_object_id >= 0 and not object_dragging
	rotate_object_button.visible = show_button
	if show_button:
		var record: Dictionary = placed_objects.get(moving_object_id, {})
		if record.is_empty():
			return
		var screen := camera.unproject_position(Vector3(int(record["x"]) - 7.5, 1.6, int(record["y"]) - 7.5))
		rotate_object_button.position = screen + Vector2(24, -20)


func _rotate_moving_object() -> void:
	if moving_object_id < 0 or not placed_objects.has(moving_object_id) or night_active:
		return
	var record: Dictionary = placed_objects[moving_object_id]
	var x := int(record["x"])
	var y := int(record["y"])
	var next_turn := (int(record["turn"]) + 1) % 4
	moving_turn = next_turn
	if not _can_move_to(x, y):
		moving_turn = int(record["turn"])
		_notify("Not enough room to rotate")
		return
	# Rotation is an immediate edit, not a preview awaiting a second click.
	var saved_hover := hover_cell
	hover_cell = Vector2i(x, y)
	_move_click()
	hover_cell = saved_hover
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())


func _can_move_to(x: int, y: int) -> bool:
	if moving_dance_tile.x >= 0:
		var target := Vector2i(x, y)
		return x > 0 and y > 0 and x < grid_width - 1 and y < SIZE - 1 and not occupied.has(target) and (not dance_tiles.has(target) or target == moving_dance_tile)
	if not placed_objects.has(moving_object_id):
		return false
	var record: Dictionary = placed_objects[moving_object_id]
	for cell in _footprint(x, y, str(record["kind"]), moving_turn):
		if cell.x <= 0 or cell.y <= 0 or cell.x >= SIZE - 1 or cell.y >= SIZE - 1:
			return false
		if occupied.has(cell) and int(object_at_cell.get(cell, -1)) != moving_object_id:
			return false
	return true


func _cancel_move() -> void:
	moving_dance_tile = Vector2i(-1, -1)
	moving_object_id = -1
	object_drag_armed = false
	object_dragging = false
	_update_rotate_button()
	_refresh_preview()


func _move_dance_tile(destination: Vector2i) -> void:
	if night_active or moving_dance_tile.x < 0 or not dance_tiles.has(moving_dance_tile):
		return
	if not _can_move_to(destination.x, destination.y):
		return
	var origin := moving_dance_tile
	if origin == destination:
		return
	var paid := bool(dance_tiles[origin].get("paid", false))
	_remove_dance_tile(origin)
	_add_dance_tile(destination, paid)
	action_history.append({"action": "tile_move", "from": origin, "to": destination})
	moving_dance_tile = destination
	_refresh_economy()
	_notify("Dance tile moved")


func _move_click() -> void:
	if moving_object_id < 0:
		if object_at_cell.has(hover_cell):
			moving_object_id = int(object_at_cell[hover_cell])
			moving_turn = int(placed_objects[moving_object_id]["turn"])
			_update_rotate_button()
			status_label.text = "SELECTED  |  Drag: move  ↻/R: rotate  ESC: deselect"
			_refresh_preview()
		elif build_kind_selected:
			_place_selected()
		return
	if not _can_move_to(hover_cell.x, hover_cell.y):
		_notify("Space occupied or outside club")
		return
	var record: Dictionary = placed_objects[moving_object_id]
	var old_x := int(record["x"])
	var old_y := int(record["y"])
	var old_turn := int(record["turn"])
	var old_record := _remove_object(moving_object_id)
	var node := _model(club, str(old_record["kind"]), hover_cell.x, hover_cell.y, moving_turn)
	var new_id := _register_object(node, str(old_record["kind"]), hover_cell.x, hover_cell.y, moving_turn)
	_attach_fixture_lighting(node, str(old_record["kind"]))
	placed_objects[new_id]["paid"] = old_record["paid"]
	action_history.append({"action": "move", "id": new_id, "x": old_x, "y": old_y, "turn": old_turn})
	moving_object_id = new_id
	moving_turn = int(placed_objects[new_id]["turn"])
	_update_rotate_button()
	status_label.text = "SELECTED  |  Drag: move  ↻/R: rotate  ESC: deselect"
	_refresh_preview()
	_refresh_economy()
	_notify("Object moved")


func _place_selected() -> void:
	if club_level < int(LEVEL_UNLOCKS.get(selected_kind, 1)):
		_notify("Unlock at level %d" % int(LEVEL_UNLOCKS[selected_kind]))
		return
	if not _can_place(hover_cell.x, hover_cell.y, selected_kind, build_turn):
		return
	if night_active:
		_notify("Finish the night before building")
		return
	var cost := _build_price(selected_kind)
	if cash < cost:
		_notify("Not enough cash  |  Need €%d" % cost)
		return
	var id := -1
	if selected_kind == "dance_tile":
		_add_dance_tile(hover_cell, cost > 0)
	else:
		var node := _model(club, selected_kind, hover_cell.x, hover_cell.y, build_turn)
		id = _register_object(node, selected_kind, hover_cell.x, hover_cell.y, build_turn)
		_attach_fixture_lighting(node, selected_kind)
		placed_objects[id]["paid"] = true
	cash -= cost
	action_history.append({"action": "tile_place", "cell": hover_cell, "cost": cost} if selected_kind == "dance_tile" else {"action": "place", "id": id, "cost": cost})
	_refresh_economy()
	_notify("Built %s  |  -€%d" % [selected_kind.capitalize(), cost])
	_refresh_preview()
	_update_hover(get_viewport().get_mouse_position())

func _enable_erase() -> void:
	_cancel_move()
	build_kind_selected = false
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
	if progression_panel != null:
		progression_panel.visible = false
	build_toggle.text = "CLOSE BUILD" if build_panel.visible else "BUILD  [B]"
	_update_hover(get_viewport().get_mouse_position())

func _toggle_help() -> void:
	help_label.visible = not help_label.visible

func _choose_kind(kind: String) -> void:
	_cancel_move()
	if night_active:
		return
	if club_level < int(LEVEL_UNLOCKS.get(kind, 1)):
		_notify("%s unlocks at level %d" % [kind.capitalize(), int(LEVEL_UNLOCKS[kind])])
		return
	selected_kind = kind
	build_kind_selected = true
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
	for y in range(SIZE):
		for x in range(SIZE):
			_make_box(club, Vector3(x - 7.5, -0.055, y - 7.5),
				Vector3(0.99, 0.10, 0.99),
				dark if (x + y) % 2 == 0 else light)
			floor_heights[Vector2i(x, y)] = -0.005
	# Sample club has six purchased tiles. New clubs start with none.
	for cell in [Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7)]:
		_add_dance_tile(cell, true)
	free_dance_tiles = 0
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
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_strength = 1.15
	env.glow_bloom = 0.22
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

func _dj_fee(index: int) -> int:
	var discount := (0.05 if unlocked_perks.has("connections") else 0.0) + (0.10 if unlocked_perks.has("resident") else 0.0)
	return roundi(float(DJ_ROSTER[index]["fee"]) * (1.0 - discount))


func _buy_perk(id: String) -> void:
	if perk_points <= 0 or unlocked_perks.has(id):
		return
	var option_index := -1
	for i in range(PERK_OPTIONS.size()):
		if PERK_OPTIONS[i]["id"] == id:
			option_index = i
			break
	if option_index < 0:
		return
	# Perks in each branch are purchased in order.
	if option_index > 0 and PERK_OPTIONS[option_index - 1]["branch"] == PERK_OPTIONS[option_index]["branch"] and not unlocked_perks.has(str(PERK_OPTIONS[option_index - 1]["id"])):
		_notify("Unlock the previous perk in this branch first")
		return
	perk_points -= 1
	unlocked_perks.append(id)
	_refresh_progression()
	_refresh_readiness()
	_notify("PERK UNLOCKED: %s" % PERK_OPTIONS[option_index]["name"])


func _can_expand_club() -> bool:
	return not expanded and not night_active and cash >= EXPANSION_PRICE and reputation >= 65 and club_level >= 4


func _apply_east_wing() -> void:
	if expanded:
		return
	expanded = true
	grid_width = EXPANDED_WIDTH
	# Extend the existing venue to the east, keeping the entrance, camera,
	# current furniture and all saved grid coordinates intact.
	for y in range(SIZE):
		for x in range(SIZE, EXPANDED_WIDTH):
			_make_box(club, Vector3(x - 7.5, -0.055, y - 7.5), Vector3(0.99, 0.10, 0.99),
				Color("#272735") if (x + y) % 2 == 0 else Color("#343342"))
			floor_heights[Vector2i(x, y)] = -0.005
	# Three-cell passage through the original eastern perimeter.
	for y in range(6, 9):
		var old_wall := club.get_node_or_null("wall_15_%d" % y)
		if old_wall != null:
			old_wall.queue_free()
	# Enclose the new wing without disturbing the original club walls.
	for x in range(SIZE, EXPANDED_WIDTH):
		_model(club, "wall", x, 0)
		_model(club, "wall", x, SIZE - 1)
	for y in range(1, SIZE - 1):
		_model(club, "wall", EXPANDED_WIDTH - 1, y, 1)
	_refresh_preview()
	_refresh_readiness()


func _remove_east_wing() -> void:
	if not expanded:
		return
	for child in club.get_children():
		if child is Node3D and (child.position.x > 7.9 or child.name.begins_with("wall_21_")):
			child.queue_free()
	for cell in floor_heights.keys():
		if cell.x >= SIZE:
			floor_heights.erase(cell)
	expanded = false
	grid_width = SIZE
	for y in range(6, 9):
		_model(club, "wall", 15, y, 1)


func _buy_expansion() -> void:
	if not _can_expand_club():
		_notify("Requires level 4, reputation 65 and €5000")
		return
	cash -= EXPANSION_PRICE
	_apply_east_wing()
	_refresh_economy()
	_refresh_progression()
	_notify("EAST WING OPEN!  Six new columns of club space.")


func _refresh_progression() -> void:
	_refresh_build_catalog()
	if progression_details == null:
		return
	var level_name: String = LEVEL_NAMES[mini(club_level - 1, LEVEL_NAMES.size() - 1)]
	progression_details.text = "LVL %d  ·  %s\n%d / %d XP   ·   %d PERK POINTS" % [club_level, level_name, club_xp, _xp_needed(club_level), perk_points]
	if xp_bar != null:
		xp_bar.max_value = maxi(1, _xp_needed(club_level))
		xp_bar.value = club_xp
	if rep_bar != null:
		rep_bar.value = reputation
	for i in range(perk_buttons.size()):
		var option: Dictionary = PERK_OPTIONS[i]
		var owned := unlocked_perks.has(str(option["id"]))
		perk_buttons[i].text = "%s  %s\n     %s" % ["✓" if owned else "✦", option["name"], option["effect"]]
		perk_buttons[i].add_theme_stylebox_override("disabled", UIStyle.perk_style(owned))
		perk_buttons[i].disabled = owned or perk_points <= 0
	if expansion_details != null:
		expansion_details.text = "EAST WING  ·  16×16 → 22×16\nCOST €%d  ·  REP %d/65  ·  LVL %d/4\n%s" % [EXPANSION_PRICE, reputation, club_level, "Expanded! Build in the new wing." if expanded else ("Ready to purchase" if _can_expand_club() else "Earn money and reputation to unlock")]
	if expansion_button != null:
		expansion_button.visible = not expanded
		expansion_button.disabled = not _can_expand_club()
		expansion_button.text = "BUY EAST WING  ·  €%d" % EXPANSION_PRICE


func _save_club() -> void:
	if night_active:
		_notify("Finish the night before saving")
		return
	var furniture: Array[Dictionary] = []
	for record in placed_objects.values():
		furniture.append({
			"kind": record["kind"], "x": record["x"], "y": record["y"],
			"turn": record["turn"], "paid": record.get("paid", false)
		})
	var tile_data: Array[Dictionary] = []
	for cell in dance_tiles:
		tile_data.append({"x": cell.x, "y": cell.y, "paid": bool(dance_tiles[cell].get("paid", false))})
	var data := {
		"version": 3, "expanded": expanded, "club_name": club_name, "cash": cash, "reputation": reputation,
		"level": club_level, "xp": club_xp, "total_xp": total_xp,
		"perk_points": perk_points, "perks": unlocked_perks,
		"milestones": completed_milestones, "profit_streak": profitable_night_streak,
		"night_number": night_number, "ticket_price": ticket_price, "drink_price": drink_price, "objects": furniture,
		"dance_tiles": tile_data, "free_dance_tiles": free_dance_tiles
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_notify("Save failed: unable to write file")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_notify("Club saved successfully")


func _load_club() -> void:
	if night_active:
		_notify("Finish the night before loading")
		return
	if not FileAccess.file_exists(SAVE_PATH):
		_notify("No saved club found")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_notify("Unable to open saved club")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		_notify("Invalid save file")
		return
	var data: Dictionary = parsed
	if not data.has("objects") or not data["objects"] is Array:
		_notify("Invalid club layout")
		return
	# Validate before removing the current club.
	for entry in data["objects"]:
		if not entry is Dictionary:
			_notify("Invalid object in save")
			return
		if not models.has(str(entry.get("kind", ""))):
			_notify("Save references an unavailable model")
			return
		var x := int(entry.get("x", -1))
		var y := int(entry.get("y", -1))
		if x < 0 or x >= grid_width or y < 0 or y >= SIZE:
			_notify("Save contains an invalid object position")
			return
	_clear_guests()
	if bool(data.get("expanded", false)) and not expanded:
		_apply_east_wing()
	elif not bool(data.get("expanded", false)) and expanded:
		_remove_east_wing()
	for id in placed_objects.keys().duplicate():
		_remove_object(int(id))
	_clear_dance_tiles()
	occupied.clear()
	object_at_cell.clear()
	action_history.clear()
	free_dance_tiles = 0
	for tile in data.get("dance_tiles", []):
		var cell := Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1)))
		if cell.x > 0 and cell.x < grid_width - 1 and cell.y > 0 and cell.y < SIZE - 1:
			_add_dance_tile(cell, bool(tile.get("paid", false)))
	for entry in data["objects"]:
		var kind := str(entry["kind"])
		var x := int(entry["x"])
		var y := int(entry["y"])
		var turn := int(entry.get("turn", 0))
		var node := _model(club, kind, x, y, turn)
		var id := _register_object(node, kind, x, y, turn)
		placed_objects[id]["paid"] = bool(entry.get("paid", false))
		_attach_fixture_lighting(node, kind)
	club_name = str(data.get("club_name", "ABLETON GYM")).strip_edges().substr(0, 28)
	if club_name.is_empty():
		club_name = "ABLETON GYM"
	_refresh_club_sign()
	cash = int(data.get("cash", STARTING_CAPITAL))
	reputation = clampi(int(data.get("reputation", 100)), 0, 100)
	club_level = maxi(1, int(data.get("level", 1)))
	club_xp = maxi(0, int(data.get("xp", 0)))
	total_xp = maxi(0, int(data.get("total_xp", 0)))
	perk_points = maxi(0, int(data.get("perk_points", 0)))
	completed_milestones.clear()
	for milestone_id in data.get("milestones", []):
		completed_milestones.append(str(milestone_id))
	profitable_night_streak = maxi(0, int(data.get("profit_streak", 0)))
	unlocked_perks.clear()
	for perk in data.get("perks", []):
		unlocked_perks.append(str(perk))
	night_number = maxi(0, int(data.get("night_number", 0)))
	ticket_price = clampi(int(data.get("ticket_price", 20)), 5, 80)
	drink_price = clampi(int(data.get("drink_price", 8)), 2, 35)
	if ticket_slider != null:
		ticket_slider.value = ticket_price
	if drink_slider != null:
		drink_slider.value = drink_price
	build_mode = false
	erase_mode = false
	_refresh_preview()
	_refresh_economy()
	_refresh_readiness()
	_notify("Club loaded successfully")


func _show_new_club_confirmation() -> void:
	# The confirmation dialog is attached to the UI theme root.
	for child in get_tree().get_nodes_in_group("nightshift_new_club_dialog"):
		if child is ConfirmationDialog:
			child.popup_centered()
			return


func _new_club() -> void:
	if night_active:
		_notify("Finish the night before starting a new club")
		return
	_cancel_move()
	_clear_guests()
	_clear_dj_performers()
	_clear_dance_tiles()
	# Remove the sample layout, including perimeter posters. Keep the floor,
	# existing perimeter walls, and the two-cell entrance.
	for id in placed_objects.keys().duplicate():
		_remove_object(int(id))
	occupied.clear()
	object_at_cell.clear()
	action_history.clear()
	free_dance_tiles = 0
	# Reset the optional east wing when starting over.
	if expanded:
		_remove_east_wing()
	# The sample club uses posters INSTEAD of walls. Restore a complete
	# perimeter for a new club, leaving only the two-cell entrance open.
	for y in range(SIZE):
		for x in range(SIZE):
			if x != 0 and x != SIZE - 1 and y != 0 and y != SIZE - 1:
				continue
			if y == SIZE - 1 and x in [7, 8]:
				continue
			if club.get_node_or_null("wall_%d_%d" % [x, y]) == null:
				_model(club, "wall", x, y, 1 if x == 0 or x == SIZE - 1 else 0)
	poster_labels.clear()
	poster_led_materials.clear()
	poster_led_accents.clear()
	poster_led_lights.clear()
	stage_lights.clear()
	disco_spots.clear()
	laser_spots.clear()
	beam_meshes.clear()
	laser_beams.clear()
	club_name = "NEW CLUB"
	club_name_edit.text = club_name
	_refresh_club_sign()
	cash = STARTING_CAPITAL
	reputation = 55
	club_level = 1
	club_xp = 0
	total_xp = 0
	perk_points = 0
	unlocked_perks.clear()
	completed_milestones.clear()
	profitable_night_streak = 0
	night_number = 0
	guest_count = 0
	night_ticket_income = 0
	night_drink_income = 0
	night_drinks_sold = 0
	night_dj_fee = 0
	last_xp_gain = 0
	last_rep_change = 0
	ticket_price = 15
	drink_price = 7
	ticket_slider.value = ticket_price
	drink_slider.value = drink_price
	if dj_picker != null:
		dj_picker.select(DJ_ROSTER.size() - 1)
		_refresh_dj_card()
	build_mode = false
	build_kind_selected = false
	erase_mode = false
	if build_panel != null:
		build_panel.hide()
	build_toggle.text = "BUILD  [B]"
	_refresh_preview()
	_refresh_prices()
	_refresh_economy()
	_update_night_stats()
	_refresh_readiness()
	_notify("NEW CLUB  |  €%d budget. Build DJ booth, 2 speakers, bar and restroom." % STARTING_CAPITAL)


func _build_overlay() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var theme_root := Control.new()
	theme_root.theme = UIStyle.make_theme()
	theme_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(theme_root)
	guest_info_panel = PanelContainer.new()
	guest_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	guest_info_panel.anchor_top = 1.0
	guest_info_panel.anchor_bottom = 1.0
	guest_info_panel.offset_left = 20.0
	guest_info_panel.offset_right = 320.0
	guest_info_panel.offset_top = -185.0
	guest_info_panel.offset_bottom = -20.0
	guest_info_panel.custom_minimum_size = Vector2(300, 165)
	guest_info_panel.visible = false
	guest_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.decorate_panel(guest_info_panel)
	theme_root.add_child(guest_info_panel)
	guest_info_panel.add_to_group("nightshift_ui_blocker")
	guest_info_label = Label.new()
	guest_info_label.custom_minimum_size = Vector2(280, 150)
	guest_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guest_info_panel.add_child(guest_info_label)
	rotate_object_button = Button.new()
	rotate_object_button.text = "↻"
	rotate_object_button.tooltip_text = "Rotate selected object 90° (R)"
	rotate_object_button.custom_minimum_size = Vector2(42, 42)
	rotate_object_button.visible = false
	rotate_object_button.mouse_filter = Control.MOUSE_FILTER_STOP
	UIStyle.decorate_button(rotate_object_button)
	rotate_object_button.pressed.connect(_rotate_moving_object)
	theme_root.add_child(rotate_object_button)
	rotate_object_button.add_to_group("nightshift_ui_blocker")
	# Compact management dropdown; all actions stay in the game.
	var manage_button := MenuButton.new()
	manage_button.text = "☰  CLUB MENU"
	manage_button.position = Vector2(20, 172)
	manage_button.custom_minimum_size = Vector2(166, 38)
	UIStyle.decorate_button(manage_button)
	theme_root.add_child(manage_button)
	manage_button.add_to_group("nightshift_ui_blocker")
	var popup := manage_button.get_popup()
	popup.add_theme_font_size_override("font_size", 13)
	popup.add_theme_stylebox_override("panel", UIStyle.panel_style())
	popup.add_item("Save Club", 0)
	popup.add_item("Load Club", 1)
	popup.add_item("New Club", 2)
	popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _save_club()
			1: _load_club()
			2: _show_new_club_confirmation()
	)
	var new_confirmation := ConfirmationDialog.new()
	new_confirmation.name = "NewClubConfirmation"
	new_confirmation.title = "Start a new club?"
	new_confirmation.add_to_group("nightshift_new_club_dialog")
	new_confirmation.dialog_text = "Your current unsaved progress will be lost. Your saved club will remain available."
	theme_root.add_child(new_confirmation)
	new_confirmation.confirmed.connect(_new_club)
	var header_panel := PanelContainer.new()
	header_panel.position = Vector2(12, 12)
	header_panel.custom_minimum_size = Vector2(480, 150)
	UIStyle.decorate_panel(header_panel)
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_root.add_child(header_panel)
	header_panel.add_to_group("nightshift_ui_blocker")
	var title := Label.new()
	title.text = "CLUB NAME"
	UIStyle.decorate_label(title, 12)
	title.add_theme_color_override("font_color", Color("#f4eafa"))
	title.position = Vector2(30, 20)
	
	theme_root.add_child(title)
	club_name_edit = LineEdit.new()
	club_name_edit.position = Vector2(30, 39)
	club_name_edit.size = Vector2(270, 32)
	club_name_edit.text = club_name
	club_name_edit.max_length = 28
	club_name_edit.placeholder_text = "Name your club"
	club_name_edit.text_changed.connect(func(value: String) -> void:
		club_name = value.strip_edges()
		_refresh_club_sign()
	)
	theme_root.add_child(club_name_edit)
	if not missing_models.is_empty():
		var warning := Label.new()
		warning.text = "Missing GLB: " + ", ".join(missing_models)
		warning.position = Vector2(300, 120)
		warning.add_theme_color_override("font_color", Color("#ffb27c"))
		theme_root.add_child(warning)
	economy_label = Label.new()
	economy_label.position = Vector2(30, 78)
	UIStyle.decorate_label(economy_label, 15)
	theme_root.add_child(economy_label)
	_refresh_economy()
	notice_label = Label.new()
	notice_label.position = Vector2(30, 107)
	UIStyle.decorate_label(notice_label, 13, true)
	theme_root.add_child(notice_label)
	status_label = Label.new()
	status_label.position = Vector2(30, 130)
	status_label.text = "MODE: CAMERA   |   B: build   X: erase   Ctrl/Cmd+Z: undo"
	UIStyle.decorate_label(status_label, 13, true)
	theme_root.add_child(status_label)
	build_toggle = Button.new()
	build_toggle.text = "BUILD  [B]"
	build_toggle.position = Vector2(20, 222)
	build_toggle.custom_minimum_size = Vector2(166, 38)
	UIStyle.decorate_button(build_toggle, true)
	build_toggle.pressed.connect(_toggle_build_panel)
	theme_root.add_child(build_toggle)
	build_toggle.add_to_group("nightshift_ui_blocker")
	build_panel = PanelContainer.new()
	build_panel.position = Vector2(20, 322)
	build_panel.visible = false
	UIStyle.decorate_panel(build_panel)
	theme_root.add_child(build_panel)
	build_panel.add_to_group("nightshift_ui_blocker")
	var choices := GridContainer.new()
	choices.columns = 2
	build_panel.add_child(choices)
	for kind in BUILD_TYPES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(142, 34)
		UIStyle.decorate_button(button)
		button.pressed.connect(_choose_kind.bind(kind))
		choices.add_child(button)
		catalog_buttons[kind] = button
	_refresh_build_catalog()
	var erase_button := Button.new()
	erase_button.text = "ERASE  [X]"
	UIStyle.decorate_button(erase_button)
	erase_button.pressed.connect(_enable_erase)
	choices.add_child(erase_button)
	var progression_toggle := Button.new()
	progression_toggle.text = "★ PROGRESSION"
	progression_toggle.position = Vector2(20, 272)
	progression_toggle.custom_minimum_size = Vector2(166, 38)
	UIStyle.decorate_button(progression_toggle, true)
	progression_toggle.pressed.connect(func() -> void:
		progression_panel.visible = not progression_panel.visible
		build_panel.visible = false
		build_toggle.text = "BUILD  [B]"
	)
	theme_root.add_child(progression_toggle)
	# Browser-style progression and perks, positioned under the build controls.
	progression_panel = PanelContainer.new()
	progression_panel.position = Vector2(20, 322)
	progression_panel.custom_minimum_size = Vector2(344, 0)
	progression_panel.visible = false
	UIStyle.decorate_panel(progression_panel)
	theme_root.add_child(progression_panel)
	progression_panel.add_to_group("nightshift_ui_blocker")
	var progress_content := VBoxContainer.new()
	progress_content.add_theme_constant_override("separation", 12)
	progression_panel.add_child(progress_content)
	var progress_heading := Label.new()
	progress_heading.text = "CLUB PROGRESSION"
	UIStyle.decorate_label(progress_heading, 17)
	progress_heading.add_theme_color_override("font_color", Color("#f0c4ed"))
	progress_content.add_child(progress_heading)
	progression_details = Label.new()
	UIStyle.decorate_label(progression_details, 14)
	progress_content.add_child(progression_details)
	xp_bar = ProgressBar.new()
	UIStyle.decorate_progress(xp_bar)
	progress_content.add_child(xp_bar)
	var reputation_heading := Label.new()
	reputation_heading.text = "REPUTATION"
	UIStyle.decorate_section(reputation_heading)
	progress_content.add_child(reputation_heading)
	rep_bar = ProgressBar.new()
	rep_bar.max_value = 100
	UIStyle.decorate_progress(rep_bar)
	progress_content.add_child(rep_bar)
	var perks_heading := Label.new()
	perks_heading.text = "MANAGER PERKS"
	UIStyle.decorate_label(perks_heading, 15)
	perks_heading.add_theme_color_override("font_color", Color("#b6c5e2"))
	progress_content.add_child(perks_heading)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(306, 235)
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_font_size_override("font_size", 13)
	progress_content.add_child(tabs)
	for branch in ["MUSIC", "BAR", "COMMUNITY"]:
		var branch_scroll := ScrollContainer.new()
		branch_scroll.name = branch.capitalize()
		branch_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(branch_scroll)
		var branch_list := VBoxContainer.new()
		branch_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch_list.add_theme_constant_override("separation", 8)
		branch_scroll.add_child(branch_list)
		for option in PERK_OPTIONS:
			if option["branch"] != branch:
				continue
			var perk_button := Button.new()
			perk_button.custom_minimum_size = Vector2(292, 62)
			perk_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			perk_button.add_theme_font_size_override("font_size", 14)
			UIStyle.decorate_button(perk_button)
			perk_button.add_theme_font_size_override("font_size", 14)
			perk_button.pressed.connect(_buy_perk.bind(str(option["id"])))
			branch_list.add_child(perk_button)
			perk_buttons.append(perk_button)
	var expansion_heading := Label.new()
	expansion_heading.text = "✦  NEXT BIG GOAL"
	UIStyle.decorate_section(expansion_heading)
	progress_content.add_child(expansion_heading)
	var goal_panel := PanelContainer.new()
	var goal_style := UIStyle.panel_style()
	goal_style.bg_color = Color("#251a32")
	goal_style.border_color = Color("#684077")
	goal_style.shadow_size = 0
	goal_panel.add_theme_stylebox_override("panel", goal_style)
	progress_content.add_child(goal_panel)
	expansion_details = Label.new()
	UIStyle.decorate_label(expansion_details, 12, true)
	expansion_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(expansion_details)
	expansion_button = Button.new()
	UIStyle.decorate_button(expansion_button)
	expansion_button.pressed.connect(_buy_expansion)
	goal_panel.add_child(expansion_button)
	_refresh_progression()
	var night_panel := PanelContainer.new()
	night_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	night_panel.offset_left = -345
	night_panel.offset_right = -16
	night_panel.offset_top = 16
	night_panel.offset_bottom = 16
	UIStyle.decorate_panel(night_panel)
	night_panel.custom_minimum_size = Vector2(275, 0)
	theme_root.add_child(night_panel)
	night_panel.add_to_group("nightshift_ui_blocker")
	var night_controls := VBoxContainer.new()
	night_controls.add_theme_constant_override("separation", 10)
	night_panel.add_child(night_controls)
	var heading := Label.new()
	heading.text = "CLUB OPENING"
	UIStyle.decorate_label(heading, 18)
	heading.add_theme_color_override("font_color", Color("#e2a2d9"))
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
	dj_picker.item_selected.connect(func(_index: int) -> void:
		_refresh_readiness()
		_refresh_dj_card()
		_refresh_poster_text()
	)
	UIStyle.decorate_option(dj_picker)
	night_controls.add_child(dj_picker)
	# Price controls: locked during the party, retained in club saves.
	var pricing_heading := Label.new()
	pricing_heading.text = "PRICING"
	UIStyle.decorate_section(pricing_heading)
	night_controls.add_child(pricing_heading)
	var ticket_row := HBoxContainer.new()
	night_controls.add_child(ticket_row)
	var ticket_caption := Label.new()
	ticket_caption.text = "TICKET PRICE"
	UIStyle.decorate_label(ticket_caption, 13)
	ticket_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticket_row.add_child(ticket_caption)
	ticket_value_label = Label.new()
	UIStyle.decorate_label(ticket_value_label, 14)
	ticket_row.add_child(ticket_value_label)
	ticket_slider = HSlider.new()
	ticket_slider.min_value = 5
	ticket_slider.max_value = 80
	ticket_slider.step = 1
	ticket_slider.value = ticket_price
	ticket_slider.value_changed.connect(func(value: float) -> void:
		ticket_price = int(value)
		_refresh_prices()
	)
	night_controls.add_child(ticket_slider)
	var drink_row := HBoxContainer.new()
	night_controls.add_child(drink_row)
	var drink_caption := Label.new()
	drink_caption.text = "DRINK PRICE"
	UIStyle.decorate_label(drink_caption, 13)
	drink_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drink_row.add_child(drink_caption)
	drink_value_label = Label.new()
	UIStyle.decorate_label(drink_value_label, 14)
	drink_row.add_child(drink_value_label)
	drink_slider = HSlider.new()
	drink_slider.min_value = 2
	drink_slider.max_value = 35
	drink_slider.step = 1
	drink_slider.value = drink_price
	drink_slider.value_changed.connect(func(value: float) -> void:
		drink_price = int(value)
		_refresh_prices()
	)
	night_controls.add_child(drink_slider)
	var dj_card := PanelContainer.new()
	var dj_card_style := UIStyle.panel_style()
	dj_card_style.bg_color = Color("#251a32")
	dj_card_style.border_color = Color("#684077")
	dj_card_style.shadow_size = 0
	dj_card.add_theme_stylebox_override("panel", dj_card_style)
	night_controls.add_child(dj_card)
	var dj_card_content := VBoxContainer.new()
	dj_card_content.add_theme_constant_override("separation", 7)
	dj_card.add_child(dj_card_content)
	var dj_kicker := Label.new()
	dj_kicker.text = "♫  NOW BOOKING"
	UIStyle.decorate_section(dj_kicker)
	dj_card_content.add_child(dj_kicker)
	dj_card_title = Label.new()
	UIStyle.decorate_label(dj_card_title, 17)
	dj_card_content.add_child(dj_card_title)
	dj_card_status = Label.new()
	UIStyle.decorate_label(dj_card_status, 12, true)
	dj_card_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dj_card_content.add_child(dj_card_status)
	dj_player = AudioStreamPlayer.new()
	dj_player.name = "ClubDJPlayer"
	add_child(dj_player)
	dj_player.finished.connect(_play_next_dj_track)
	_refresh_dj_card()
	_refresh_prices()
	start_night_button = Button.new()
	start_night_button.text = "START NIGHT"
	UIStyle.decorate_button(start_night_button, true)
	start_night_button.pressed.connect(_night_button_pressed)
	start_night_button.custom_minimum_size = Vector2(255, 48)
	night_controls.add_child(start_night_button)
	night_time_label = Label.new()
	night_time_label.text = "3-MINUTE NIGHT  |  TICKETS €%d  |  DRINKS €%d" % [ticket_price, drink_price]
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
		night_speed = 2.0 if night_speed == 1.0 else (4.0 if night_speed == 2.0 else 1.0)
		night_speed_button.text = "%d× SPEED" % int(night_speed)
	)
	speed_controls.add_child(night_speed_button)
	night_report_panel = PanelContainer.new()
	night_report_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	night_report_panel.offset_left = -345
	night_report_panel.offset_right = -16
	night_report_panel.offset_top = 330
	night_report_panel.offset_bottom = 330
	night_report_panel.custom_minimum_size = Vector2(275, 0)
	night_report_panel.visible = false
	UIStyle.decorate_panel(night_report_panel)
	theme_root.add_child(night_report_panel)
	night_report_panel.add_to_group("nightshift_ui_blocker")
	# Scroll the whole right HUD as one column, preserving panel order.
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightHUDScroll"
	right_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_scroll.anchor_left = 1.0
	right_scroll.anchor_right = 1.0
	right_scroll.offset_left = -365
	right_scroll.offset_right = -8
	right_scroll.offset_top = 8
	right_scroll.offset_bottom = -8
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	theme_root.add_child(right_scroll)
	right_scroll.add_to_group("nightshift_ui_blocker")
	var right_stack := VBoxContainer.new()
	right_stack.add_theme_constant_override("separation", 12)
	right_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_stack)
	theme_root.remove_child(night_panel)
	right_stack.add_child(night_panel)
	night_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	night_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_panel.offset_left = 0
	night_panel.offset_top = 0
	night_panel.offset_right = 0
	night_panel.offset_bottom = 0
	theme_root.remove_child(night_report_panel)
	right_stack.add_child(night_report_panel)
	night_report_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	night_report_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	night_report_panel.offset_left = 0
	night_report_panel.offset_top = 0
	night_report_panel.offset_right = 0
	night_report_panel.offset_bottom = 0
	# Give the report its own wheel-controlled viewport; it must not enlarge the HUD.
	var report_scroll := ScrollContainer.new()
	report_scroll.name = "NightReportScroll"
	report_scroll.custom_minimum_size = Vector2(0, 260)
	report_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	report_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	night_report_panel.add_child(report_scroll)
	report_scroll.add_to_group("nightshift_ui_blocker")
	var report_content := VBoxContainer.new()
	report_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(report_content)
	night_report_heading = Label.new()
	UIStyle.decorate_label(night_report_heading, 17)
	night_report_heading.add_theme_color_override("font_color", Color("#e2a2d9"))
	report_content.add_child(night_report_heading)
	night_report_details = Label.new()
	UIStyle.decorate_label(night_report_details, 13)
	report_content.add_child(night_report_details)
	_refresh_readiness()
	var help_button := Button.new()
	help_button.text = "?  HELP"
	help_button.position = Vector2(200, 272)
	UIStyle.decorate_button(help_button)
	help_button.pressed.connect(_toggle_help)
	theme_root.add_child(help_button)
	help_label = Label.new()
	help_label.text = "Drag: rotate   Shift+drag: pan\nWheel/pinch or +/-: zoom\nR: rotate furniture / reset camera\nB: build   X: erase   Ctrl/Cmd+Z: undo"
	help_label.position = Vector2(330, 272)
	help_label.visible = false
	UIStyle.decorate_label(help_label, 13, true)
	theme_root.add_child(help_label)

func _make_sign_board(parent: Node3D, name: String, size: Vector2, position: Vector3) -> Node3D:
	var board := Node3D.new()
	board.name = name
	board.position = position
	parent.add_child(board)
	var backing := MeshInstance3D.new()
	backing.name = "DarkMetalBacking"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.075)
	backing.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#14101d")
	mat.metallic = 0.65
	mat.roughness = 0.35
	backing.material_override = mat
	board.add_child(backing)
	var border := MeshInstance3D.new()
	border.name = "VioletBorder"
	var rim := BoxMesh.new()
	rim.size = Vector3(size.x + 0.08, size.y + 0.08, 0.035)
	border.mesh = rim
	border.position.z = -0.055
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color("#643c82")
	rim_mat.emission_enabled = true
	rim_mat.emission = Color("#a95de8")
	rim_mat.emission_energy_multiplier = 0.25
	border.material_override = rim_mat
	board.add_child(border)
	return board


func _make_sign_letters(board: Node3D, name: String, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.name = name
	label.position.z = 0.052
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color("#e9c8ff")
	label.outline_modulate = Color("#24112f")
	label.outline_size = 6
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.double_sided = false
	label.no_depth_test = false
	board.add_child(label)
	return label


func _rozzo_beat() -> float:
	if not night_active or dj_picker == null or dj_picker.selected < 0:
		return -1.0
	var dj: Dictionary = DJ_ROSTER[dj_picker.selected]
	if not dj.has("bpm"):
		return -1.0
	var beat_phase := fposmod(music_beat_clock * float(dj["bpm"]) / 60.0, 1.0)
	return pow(1.0 - beat_phase, 4.0)


func _animate_poster_leds(delta: float) -> void:
	if night_active and not night_paused:
		poster_led_clock += delta * night_speed
		music_beat_clock += delta * night_speed
	var pulse := 0.5 + 0.5 * sin(poster_led_clock * 3.5)
	var synced_beat := _rozzo_beat()
	if synced_beat >= 0.0:
		pulse = synced_beat
	for material in poster_led_materials:
		if material != null:
			material.emission_energy_multiplier = 0.08 + (7.0 + 3.0 * pulse if night_active else 0.0)
	for accent in poster_led_accents:
		if accent != null:
			accent.emission_energy_multiplier = (10.0 + 4.0 * pulse) if night_active else 0.2
	for light in poster_led_lights:
		if is_instance_valid(light):
			light.light_energy = (0.8 + 0.5 * pulse) if night_active else 0.0


func _attach_poster_text(node: Node3D) -> void:
	# The poster pivot is already rotated toward the club interior.
	# Fit the screen to the actual poster top, preserving its current bottom edge.
	# Measure before adding the screen so it cannot affect the GLB bounds.
	var poster_top := _visual_bounds(node).end.y
	var screen_bottom := 0.99 - 1.95 * 0.5
	var screen_height := maxf(0.01, poster_top - screen_bottom)
	var board := _make_sign_board(node, "DJPosterBoard", Vector2(0.86, screen_height), Vector3(0, screen_bottom + screen_height * 0.5, 0.16))
	# LED face sits slightly in front of the existing backing and rim.
	var face := MeshInstance3D.new()
	face.name = "LEDFace"
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.835, maxf(0.01, screen_height - 0.025), 0.008)
	face.mesh = face_mesh
	face.position.z = 0.042
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color("#140526")
	led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led_mat.emission_enabled = true
	led_mat.emission = Color("#a239ff")
	led_mat.emission_energy_multiplier = 0.08
	face.material_override = led_mat
	board.add_child(face)
	poster_led_materials.append(led_mat)
	# Bright thin horizontal LED accents give the screen a recognizable club look.
	for edge_y in [-1.0, 1.0]:
		var accent := MeshInstance3D.new()
		accent.name = "LEDAccent"
		var strip := BoxMesh.new()
		strip.size = Vector3(0.81, 0.014, 0.012)
		accent.mesh = strip
		accent.position = Vector3(0, edge_y * (screen_height * 0.5 - 0.035), 0.054)
		var accent_mat := StandardMaterial3D.new()
		accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		accent_mat.albedo_color = Color("#bd58ff")
		accent_mat.emission_enabled = true
		accent_mat.emission = Color("#c963ff")
		accent_mat.emission_energy_multiplier = 0.2
		accent.material_override = accent_mat
		board.add_child(accent)
		poster_led_accents.append(accent_mat)
	# Emissive materials alone do not illuminate nearby geometry.
	var led_light := OmniLight3D.new()
	led_light.name = "LEDSpill"
	led_light.position = Vector3(0, 0, 0.32)
	led_light.light_color = Color("#b36aff")
	led_light.omni_range = 2.3
	led_light.shadow_enabled = false
	led_light.light_energy = 0.0
	board.add_child(led_light)
	poster_led_lights.append(led_light)
	var label := _make_sign_letters(board, "DJPosterText", 56, 0.0019)
	label.position.z = 0.09
	label.position.y = 0.0
	poster_labels.append(label)
	_refresh_poster_text()


func _attach_entrance_sign(node: Node3D) -> void:
	# Entrance pivot has a PI rotation. Turn the sign back toward the outside (+Z).
	var board := _make_sign_board(node, "ClubMarquee", Vector2(2.45, 0.47), Vector3(0, 2.02, 0.02))
	board.rotation.y = PI * 0.5
	entrance_sign = _make_sign_letters(board, "ClubNameSign", 64, 0.0032)
	_refresh_club_sign()


func _set_sign_glow(label: Label3D, active: bool) -> void:
	label.modulate = Color("#ffffff") if active else Color("#e9c8ff")
	label.outline_modulate = Color("#8b33b9") if active else Color("#24112f")
	label.outline_size = 12 if active else 6


func _refresh_club_sign() -> void:
	if is_instance_valid(entrance_sign):
		entrance_sign.text = club_name.to_upper() if not club_name.is_empty() else "NIGHTSHIFT"
		_set_sign_glow(entrance_sign, night_active)


func _refresh_poster_text() -> void:
	var dj_name := "TONIGHT"
	if dj_picker != null and dj_picker.selected >= 0:
		dj_name = str(DJ_ROSTER[dj_picker.selected]["name"]).to_upper()
	for label in poster_labels:
		if is_instance_valid(label) and not label.is_queued_for_deletion():
			label.text = dj_name if night_active else "UP NEXT\n" + dj_name
			_set_sign_glow(label, night_active)
			label.modulate = Color(2.0, 2.0, 2.0, 1.0) if night_active else Color("#aa88c2")
			label.outline_modulate = Color(1.46, 0.79, 2.0, 1.0) if night_active else Color("#24112f")


func _pointer_over_ui(position: Vector2) -> bool:
	# Controls in the CanvasLayer own pointer interactions; 3D camera must not react.
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return true
	for node in get_tree().get_nodes_in_group("nightshift_ui_blocker"):
		if node is Control and node.is_visible_in_tree() and node.get_global_rect().has_point(position):
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and object_drag_armed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not object_dragging and event.position.distance_to(object_drag_start) > 9.0:
			object_dragging = true
			_refresh_preview()
			_update_rotate_button()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and object_drag_armed:
		object_drag_armed = false
		if object_dragging:
			_update_hover(event.position)
			if _can_move_to(hover_cell.x, hover_cell.y):
				if moving_dance_tile.x >= 0:
					_move_dance_tile(hover_cell)
				else:
					_move_click()
			else:
				_notify("Cannot move there")
			object_dragging = false
			_refresh_preview()
			_update_rotate_button()
		return
	# Ignore pointer input on HUD, including sliders and dropdowns.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
	if event is InputEventMouseMotion and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
	if (event is InputEventMouse or event is InputEventPanGesture or event is InputEventMagnifyGesture) and _pointer_over_ui(event.position):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
		return
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
	if event is InputEventMouseMotion and (build_mode or object_dragging or moving_object_id >= 0):
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
		if event.button_index == MOUSE_BUTTON_LEFT and (build_mode or not night_active):
			if event.pressed and not (build_panel.visible and build_panel.get_global_rect().has_point(event.position)) and not build_toggle.get_global_rect().has_point(event.position) and not night_active:
				_update_hover(event.position)
				if erase_mode and build_mode:
					_erase_hovered()
				elif build_kind_selected and build_mode:
					_move_click()
				elif dance_tiles.has(hover_cell) and not object_at_cell.has(hover_cell):
					moving_object_id = -1
					moving_dance_tile = hover_cell
					object_drag_armed = true
					object_drag_start = event.position
					status_label.text = "DANCE TILE SELECTED  |  Drag: move  ESC: deselect"
					_update_rotate_button()
				elif object_at_cell.has(hover_cell):
					moving_dance_tile = Vector2i(-1, -1)
					var clicked_id := int(object_at_cell[hover_cell])
					if moving_object_id != clicked_id:
						moving_object_id = -1
						_move_click()
					object_drag_armed = true
					object_drag_start = event.position
				else:
					object_drag_armed = false
					if moving_object_id >= 0 or moving_dance_tile.x >= 0:
						_cancel_move()
					# Empty floor still rotates the camera in normal mode.
					if not build_mode:
						dragging = true
						last_mouse = event.position
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and night_active and _select_guest_at(event.position):
				return
			if event.pressed:
				var over_ui := false
				if build_toggle != null and build_toggle.get_global_rect().has_point(event.position):
					over_ui = true
				if build_panel != null and build_panel.visible and build_panel.get_global_rect().has_point(event.position):
					over_ui = true
				dragging = not over_ui and not _pointer_over_ui(event.position)
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
		build_kind_selected = false
		_cancel_move()
		if not build_mode:
			erase_mode = false
		dragging = false
		status_label.text = ("BUILD: %s  |  Click: place  R: rotate  ESC: exit" % selected_kind.to_upper()) if build_mode else "MODE: CAMERA   |   B: build   ESC: camera"
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if moving_object_id >= 0:
			_cancel_move()
			return
		build_mode = false
		build_kind_selected = false
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
		if moving_object_id >= 0:
			_rotate_moving_object()
		elif build_kind_selected:
			build_turn = (build_turn + 1) % 4
		_refresh_preview()
		_update_hover(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = deg_to_rad(45)
		tilt = deg_to_rad(-55)
		zoom = 16
		pivot.position = Vector3.ZERO
		_update_camera()
