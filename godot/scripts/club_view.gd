extends Node3D
## First migration milestone: a playable 3D camera and procedural club shell.
## Controls: left-drag rotate, shift+left-drag pan, wheel zoom, R reset.

const SIZE := 16
const TILE := 1.0
const MIN_ZOOM := 5.0
const MAX_ZOOM := 27.0

var camera: Camera3D
var pivot: Node3D
var zoom := 13.0
var yaw := deg_to_rad(45.0)
var tilt := deg_to_rad(-55.0)
var dragging := false
var last_mouse := Vector2.ZERO

func _ready() -> void:
	_build_world()
	_build_camera()
	_build_overlay()

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

func _model(parent: Node3D, kind: String, x: int, y: int, turn: int = 0) -> void:
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
	if kind == "poster":
		# Face the artwork into the room on each perimeter side.
		if x == 0:
			pivot_node.rotation.y = PI * 0.5
		elif x == SIZE - 1:
			pivot_node.rotation.y = -PI * 0.5
		elif y == 0:
			pivot_node.rotation.y = PI
	if not models.has(kind):
		var color := Color("#5d456a") if kind in TWO_CELL else Color("#53505b")
		_make_box(pivot_node, Vector3(0, 0.4, 0.5 if kind in TWO_CELL else 0),
			Vector3(0.8, 0.8, 1.8 if kind in TWO_CELL else 0.8), color)
		return

	var visual := (models[kind] as PackedScene).instantiate() as Node3D
	pivot_node.add_child(visual)
	var bounds := _visual_bounds(visual)
	var native_width := minf(bounds.size.x, bounds.size.z)
	var native_length := maxf(bounds.size.x, bounds.size.z)
	if bounds.size.length_squared() < 0.000001:
		push_warning("NightShift: empty model %s" % kind)
		return

	# All two-cell objects occupy the local +Z direction before grid rotation.
	if kind in TWO_CELL and bounds.size.x > bounds.size.z:
		# Orient the authored long side along local Z before grid rotation.
		visual.rotation.y = PI * 0.5
		bounds = _visual_bounds(visual)

	var target_x := 0.9
	var target_z := 0.9
	if kind in TWO_CELL:
		target_x = 0.94
		target_z = 1.88
	elif kind == "stool":
		target_x = 0.53
		target_z = 0.53
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
	if kind in TWO_CELL:
		fit_scale = minf(target_z / maxf(native_length, 0.001),
			target_x / maxf(native_width, 0.001))
		# Measure the original GLB before rotating it: imported node transforms
		# can make rotated AABBs report the wrong length during this frame.
	else:
		fit_scale = minf(target_x / maxf(bounds.size.x, 0.001),
			target_z / maxf(bounds.size.z, 0.001))
	# Do not shrink large furniture merely because its authored height is tall.
	if kind == "stool":
		fit_scale = minf(fit_scale, 0.65 / maxf(bounds.size.y, 0.001))
	elif kind == "floor":
		fit_scale = minf(fit_scale, 0.22 / maxf(bounds.size.y, 0.001))
	visual.scale = Vector3.ONE * fit_scale
	bounds = _visual_bounds(visual)
	# Bottom of the geometry rests on top of the base floor, not inside it.
	# The footprint center is half a cell forward for two-cell objects.
	var offset_z := 0.5 if kind in TWO_CELL and kind != "entrance" else 0.0
	var base_y := 0.0 if kind == "floor" else 0.015
	visual.position += Vector3(-bounds.get_center().x,
		base_y - bounds.position.y,
		offset_z - bounds.get_center().z)

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
		_model(club, item[2], item[0], item[1], item[3])
	_model(club, "entrance", 7, 15, 1)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#131a2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d4c7ed")
	env.ambient_light_energy = 0.85
	ambient.environment = env
	add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.0
	add_child(sun)

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
	title.text = "NIGHTSHIFT  /  GODOT PROTOTYPE"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)
	if not missing_models.is_empty():
		var warning := Label.new()
		warning.text = "Missing GLB: " + ", ".join(missing_models)
		warning.position = Vector2(20, 95)
		warning.add_theme_color_override("font_color", Color("#ffb27c"))
		ui.add_child(warning)
	var help := Label.new()
	help.text = "Drag: rotate   Shift+drag: pan   Wheel/pinch or +/-: zoom   R: reset"
	help.position = Vector2(20, 58)
	ui.add_child(help)

func _input(event: InputEvent) -> void:
	# Handle scrolling even when a UI Control consumes unhandled input.
	if event is InputEventMagnifyGesture:
		zoom = clamp(zoom / maxf(event.factor, 0.01), MIN_ZOOM, MAX_ZOOM)
		_update_camera()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		# macOS may send smooth scrolling as a pan gesture rather than wheel buttons.
		if absf(event.delta.y) > 0.001:
			zoom = clampf(zoom * exp(event.delta.y * 0.055), MIN_ZOOM, MAX_ZOOM)
			_update_camera()
			get_viewport().set_input_as_handled()
		return
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
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
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
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD):
		zoom = max(MIN_ZOOM, zoom * 0.85)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT):
		zoom = min(MAX_ZOOM, zoom * 1.15)
		_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = deg_to_rad(45)
		tilt = deg_to_rad(-55)
		zoom = 13
		pivot.position = Vector3.ZERO
		_update_camera()
