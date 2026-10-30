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

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "Club"
	add_child(world)
	var dark := Color("#272735")
	var light := Color("#343342")
	var purple := Color("#6a3b7d")
	var concrete := Color("#4c4b53")
	for y in range(SIZE):
		for x in range(SIZE):
			var pos := Vector3(x - (SIZE - 1) * 0.5, -0.055, y - (SIZE - 1) * 0.5)
			var dance := x >= 3 and x <= 12 and y >= 3 and y <= 9
			var tile_color := purple if dance else (dark if (x + y) % 2 == 0 else light)
			_make_box(world, pos + Vector3(0, 0.085 if dance else 0, 0),
				Vector3(0.98, 0.17 if dance else 0.10, 0.98), tile_color)
	for i in range(SIZE):
		var p := i - (SIZE - 1) * 0.5
		_make_box(world, Vector3(p, 0.65, -(SIZE - 1) * 0.5),
			Vector3(0.99, 1.3, 0.16), concrete)
		_make_box(world, Vector3(-(SIZE - 1) * 0.5, 0.65, p),
			Vector3(0.16, 1.3, 0.99), concrete)
		_make_box(world, Vector3((SIZE - 1) * 0.5, 0.65, p),
			Vector3(0.16, 1.3, 0.99), concrete)
		if i < 7 or i > 8:
			_make_box(world, Vector3(p, 0.65, (SIZE - 1) * 0.5),
				Vector3(0.99, 1.3, 0.16), concrete)
	# Temporary geometry: actual GLB models and saved ABLETON GYM layout come next.
	_make_box(world, Vector3(0, 0.42, 2.5), Vector3(2, 0.85, 0.8), Color("#34283e"))
	_make_box(world, Vector3(-4.5, 0.48, -5.5), Vector3(2, 0.95, 0.7), Color("#50334e"))
	_make_box(world, Vector3(4.5, 0.48, -5.5), Vector3(2, 0.95, 0.7), Color("#50334e"))
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
	var help := Label.new()
	help.text = "Drag: rotate   Shift+drag: pan   Wheel: zoom   R: reset"
	help.position = Vector2(20, 58)
	ui.add_child(help)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = max(MIN_ZOOM, zoom * 0.9)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = min(MAX_ZOOM, zoom * 1.1)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		if Input.is_key_pressed(KEY_SHIFT):
			pivot.position += pivot.basis.x * (-delta.x * 0.012) + Vector3(0, 0, 1) * (-delta.y * 0.012)
		else:
			yaw -= delta.x * 0.007
			tilt = clamp(tilt + delta.y * 0.005, deg_to_rad(-85), deg_to_rad(-20))
			_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		yaw = deg_to_rad(45)
		tilt = deg_to_rad(-55)
		zoom = 13
		pivot.position = Vector3.ZERO
		_update_camera()
