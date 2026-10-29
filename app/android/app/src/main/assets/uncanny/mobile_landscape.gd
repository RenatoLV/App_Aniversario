extends Node
## Keep the entire desktop 768 x 512 frame, including its original HUD.
## This loose Android asset overrides the old portrait entry point without
## rebuilding or altering the verified original PCK.

var original: SubViewport
var frame: TextureRect
var captured := false
var previous_size := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The preserved pack still declares portrait. Override its engine setting as
	# well as the Activity manifest, otherwise Godot can rotate Android back.
	if OS.has_feature("android"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	get_tree().quit_on_go_back = false
	original = SubViewport.new()
	original.size = Vector2i(768, 512)
	original.world_2d = World2D.new()
	original.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	original.handle_input_locally = true
	original.physics_object_picking = true
	add_child(original)
	original.notify_mouse_entered()
	frame = TextureRect.new()
	frame.texture = original.get_texture()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	original.add_child(load("res://assetsNEW/scenes/master.tscn").instantiate())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	relayout()

func _process(_delta: float) -> void:
	if previous_size != get_viewport().get_visible_rect().size:
		relayout()

func relayout() -> void:
	previous_size = get_viewport().get_visible_rect().size
	var factor := minf(previous_size.x / 768.0, previous_size.y / 512.0)
	frame.size = Vector2(768, 512) * factor
	frame.position = (previous_size - frame.size) / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F10:
		Master.save_data.write_save()
		get_tree().quit()
		return
	if event is InputEventMouse:
		if not captured and not frame.get_rect().has_point(event.position):
			return
		var mapped: Vector2 = (event.position - frame.position) / frame.size * Vector2(768, 512)
		var forwarded: InputEventMouse = event.duplicate()
		forwarded.position = mapped
		forwarded.global_position = mapped
		if forwarded is InputEventMouseMotion:
			forwarded.relative = event.relative / frame.size * Vector2(768, 512)
		if forwarded is InputEventMouseButton:
			var hover := InputEventMouseMotion.new()
			hover.position = mapped
			hover.global_position = mapped
			original.push_input(hover, true)
			captured = forwarded.pressed
		original.push_input(forwarded, true)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		original.push_input(event, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Input.action_press("Pause")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("Pause")
