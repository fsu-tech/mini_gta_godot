extends CanvasLayer

@export var force_preview := false
@export var joystick_radius := 86.0
@export var look_sensitivity := 0.0032

var player: CharacterBody3D
var car: CharacterBody3D
var root_control: Control
var joystick_base: Panel
var joystick_knob: Panel
var jump_button: Button
var action_button: Button
var weapon_button: Button
var shoot_button: Button
var joystick_touch := -1
var look_touch := -1
var joystick_value := Vector2.ZERO
var vehicle_mode := false
var controls_enabled := true
var mobile_active := false

func _ready() -> void:
	player = get_node("../Player")
	car = get_node("../Car")
	mobile_active = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or force_preview
	_build_interface()
	root_control.visible = mobile_active
	get_viewport().size_changed.connect(_layout_interface)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		mobile_active = not mobile_active
		root_control.visible = mobile_active
		_release_movement()

func _process(_delta: float) -> void:
	if not mobile_active or not controls_enabled:
		return
	_apply_axis("move_left", maxf(-joystick_value.x, 0.0))
	_apply_axis("move_right", maxf(joystick_value.x, 0.0))
	_apply_axis("move_forward", maxf(-joystick_value.y, 0.0))
	_apply_axis("move_back", maxf(joystick_value.y, 0.0))
	_apply_axis("run", 1.0 if joystick_value.length() >= 0.82 and not vehicle_mode else 0.0)

func _input(event: InputEvent) -> void:
	if not mobile_active or not controls_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_touch == -1 and event.position.x < get_viewport().get_visible_rect().size.x * 0.43:
				joystick_touch = event.index
				_update_joystick(event.position)
			elif look_touch == -1 and not _point_over_button(event.position):
				look_touch = event.index
		elif event.index == joystick_touch:
			joystick_touch = -1
			joystick_value = Vector2.ZERO
			joystick_knob.position = joystick_base.position + Vector2(joystick_radius, joystick_radius) - joystick_knob.size * 0.5
			_release_movement()
		elif event.index == look_touch:
			look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch:
			_update_joystick(event.position)
		elif event.index == look_touch:
			if vehicle_mode:
				car.apply_mobile_look(event.relative, look_sensitivity)
			else:
				player.apply_mobile_look(event.relative, look_sensitivity)

func set_vehicle_mode(value: bool) -> void:
	vehicle_mode = value
	jump_button.visible = not value
	weapon_button.visible = not value
	shoot_button.visible = not value
	action_button.text = "SALIR" if value else "ACCIÓN"

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	root_control.visible = mobile_active and value
	if not value:
		_release_movement()

func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "TouchInterface"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	joystick_base = Panel.new()
	joystick_base.name = "JoystickBase"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.size = Vector2.ONE * joystick_radius * 2.0
	joystick_base.add_theme_stylebox_override("panel", _circle_style(Color(0.04, 0.06, 0.07, 0.48), Color(1, 1, 1, 0.42), 3))
	root_control.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "JoystickKnob"
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.size = Vector2.ONE * 78.0
	joystick_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.95, 0.66, 0.12, 0.82), Color(1, 0.88, 0.48, 0.9), 3))
	root_control.add_child(joystick_knob)

	jump_button = _make_button("SALTAR", Vector2(116, 76))
	action_button = _make_button("ACCIÓN", Vector2(124, 76))
	weapon_button = _make_button("ARMA", Vector2(108, 68))
	shoot_button = _make_button("DISPARAR", Vector2(132, 82), Color(0.67, 0.12, 0.1, 0.84))
	_bind_action_button(jump_button, "jump")
	_bind_action_button(action_button, "interact")
	weapon_button.pressed.connect(player.mobile_toggle_pistol)
	shoot_button.pressed.connect(player.mobile_shoot)
	_layout_interface()

func _layout_interface() -> void:
	if not root_control:
		return
	var size := get_viewport().get_visible_rect().size
	joystick_base.position = Vector2(54.0, size.y - joystick_base.size.y - 48.0)
	joystick_knob.position = joystick_base.position + Vector2(joystick_radius, joystick_radius) - joystick_knob.size * 0.5
	shoot_button.position = Vector2(size.x - 158.0, size.y - 154.0)
	jump_button.position = Vector2(size.x - 292.0, size.y - 102.0)
	action_button.position = Vector2(size.x - 154.0, size.y - 252.0)
	weapon_button.position = Vector2(size.x - 288.0, size.y - 208.0)

func _make_button(label: String, button_size: Vector2, color := Color(0.04, 0.06, 0.07, 0.7)) -> Button:
	var button := Button.new()
	button.text = label
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _rounded_style(color, Color(1, 1, 1, 0.5)))
	button.add_theme_stylebox_override("pressed", _rounded_style(color.lightened(0.22), Color(1, 0.82, 0.3, 0.95)))
	button.add_theme_stylebox_override("hover", _rounded_style(color.lightened(0.08), Color(1, 1, 1, 0.65)))
	root_control.add_child(button)
	return button

func _bind_action_button(button: Button, action: StringName) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))

func _update_joystick(screen_position: Vector2) -> void:
	var center := joystick_base.position + Vector2.ONE * joystick_radius
	var offset := (screen_position - center).limit_length(joystick_radius)
	joystick_value = offset / joystick_radius
	joystick_knob.position = center + offset - joystick_knob.size * 0.5

func _apply_axis(action: StringName, strength) -> void:
	var value := float(strength)
	if value > 0.02:
		Input.action_press(action, value)
	else:
		Input.action_release(action)

func _release_movement() -> void:
	joystick_value = Vector2.ZERO
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back", &"run", &"jump", &"interact"]:
		Input.action_release(action)

func _point_over_button(point: Vector2) -> bool:
	for button in [jump_button, action_button, weapon_button, shoot_button]:
		if button.visible and Rect2(button.position, button.size).has_point(point):
			return true
	return false

func _circle_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := _rounded_style(fill, border)
	style.corner_radius_top_left = 100
	style.corner_radius_top_right = 100
	style.corner_radius_bottom_left = 100
	style.corner_radius_bottom_right = 100
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style

func _rounded_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	return style
