extends Node
## Present the original game's render in portrait, without changing its maps,
## camera, physics or fixed-coordinate menus. Touches use the inverse mapping.

var original: SubViewport
var master: Node
var field: TextureRect
var logo: TextureRect
var stats: TextureRect
var thought: TextureRect
var background: TextureRect
var full_intro := true
var captured: TextureRect
var previous_size := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	original = SubViewport.new()
	original.name = "OriginalGame"
	original.size = Vector2i(768, 512)
	original.world_2d = World2D.new()
	original.transparent_bg = true
	original.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	original.handle_input_locally = true
	original.physics_object_picking = true
	add_child(original)
	original.notify_mouse_entered()
	# A full-screen original texture covers the areas outside the square course.
	background = TextureRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.modulate = Color(0.3, 0.3, 0.3)
	add_child(background)
	field = make_region(Rect2(0, 0, 768, 512))
	logo = make_region(Rect2(0, 0, 248, 128))
	stats = make_region(Rect2(0, 128, 248, 216))
	thought = make_region(Rect2(0, 328, 248, 184))
	master = load("res://assetsNEW/scenes/master.tscn").instantiate()
	original.add_child(master)
	# Reuse the original backdrop asset, rather than introducing replacement art.
	background.texture = master.get_node("HUD/Bg").texture
	master.get_node("HUD/Bar").hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	relayout()

func make_region(region: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = original.get_texture()
	atlas.region = region
	atlas.filter_clip = true
	var view := TextureRect.new()
	view.texture = atlas
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	return view

func _process(_delta: float) -> void:
	var intro := false
	for overlay in master.overlays:
		if overlay is StartCracktro:
			intro = true
	if intro != full_intro or previous_size != get_viewport().get_visible_rect().size:
		full_intro = intro
		relayout()

func relayout() -> void:
	var screen := get_viewport().get_visible_rect().size
	previous_size = screen
	background.size = screen
	var width := screen.x
	var field_height := width * (512.0 / 768.0 if full_intro else 1.0)
	field.texture.region = Rect2(0, 0, 768, 512) if full_intro else Rect2(256, 0, 512, 512)
	# Keep every part of the course visible; never stretch or crop its geometry.
	field.position = Vector2(0, maxf(96, (screen.y - field_height - 208) * 0.35))
	field.size = Vector2(width, field_height)
	logo.visible = not full_intro
	stats.visible = not full_intro
	thought.visible = not full_intro
	var logo_height := minf(width * 0.45 * 128 / 248, field.position.y - 24)
	logo.size = Vector2(logo_height * 248 / 128, logo_height)
	logo.position = Vector2((width - logo.size.x) / 2, maxf(16, (field.position.y - logo.size.y) / 2))
	# Reserve finger-sized native controls even on short, 16:9 phones.
	var remaining := screen.y - field.position.y - field_height - 208
	var side_width := minf(width * 0.46, maxf(0, remaining) * 248 / 216)
	stats.size = Vector2(side_width, side_width * 216 / 248)
	thought.size = Vector2(side_width, side_width * 184 / 248)
	stats.position = Vector2(width * 0.04, field.position.y + field_height + 16)
	thought.position = Vector2(width * 0.96 - side_width, stats.position.y)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F10:
		Master.save_data.write_save()
		get_tree().quit()
		return
	if event is InputEventMouse:
		var view: TextureRect = captured
		if not is_instance_valid(view):
			for candidate in [field, logo, stats, thought]:
				if candidate.visible and candidate.get_rect().has_point(event.position):
					view = candidate
					break
		if not is_instance_valid(view):
			return
		var region: Rect2 = view.texture.region
		var mapped: Vector2 = (event.position - view.position) / view.size * region.size + region.position
		var forwarded: InputEventMouse = event.duplicate()
		forwarded.position = mapped
		forwarded.global_position = mapped
		if forwarded is InputEventMouseMotion:
			forwarded.relative = event.relative / view.size * region.size
		if forwarded is InputEventMouseButton:
			# A tap may arrive without a preceding mouse-motion event on Android.
			var hover := InputEventMouseMotion.new()
			hover.position = mapped
			hover.global_position = mapped
			original.push_input(hover, true)
			captured = view if forwarded.pressed else null
		original.push_input(forwarded, true)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		original.push_input(event, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Input.action_press("Pause")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("Pause")
