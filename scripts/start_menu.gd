extends Control

@onready var main_menu: Control = $MainMenu
@onready var controls_panel: Control = $ControlsPanel
@onready var intro_panel: Control = $IntroPanel
@onready var intro_title: Label = $IntroPanel/IntroTitle
@onready var intro_text: Label = $IntroPanel/IntroText
@onready var fade: ColorRect = $Fade
@onready var play_button: Button = $MainMenu/MenuBox/PlayButton

var intro_running := false
var intro_token := 0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    main_menu.visible = true
    controls_panel.visible = false
    intro_panel.visible = false
    fade.modulate.a = 1.0
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    create_tween().tween_property(fade, "modulate:a", 0.0, 0.75)
    play_button.grab_focus()

func _on_play_pressed() -> void:
    if intro_running:
        return
    intro_running = true
    intro_token += 1
    var token := intro_token
    play_button.disabled = true
    await _fade_to_black(0.35)
    if token != intro_token:
        return
    main_menu.visible = false
    intro_panel.visible = true
    intro_title.modulate.a = 0.0
    intro_text.modulate.a = 0.0
    await _fade_from_black(0.55)
    await _show_intro_message("UNA CIUDAD SIN LEY", "Las calles parecen tranquilas, pero cada esquina esconde una oportunidad.", 2.4, token)
    await _show_intro_message("TU PRIMERA MISIÓN", "Explora la ciudad y llega hasta el marcador amarillo indicado en el radar.", 2.7, token)
    await _show_intro_message("ELIGE TU CAMINO", "Camina, corre, conduce y utiliza tu revólver cuando sea necesario.", 2.7, token)
    if token == intro_token:
        await _start_game()

func _show_intro_message(title: String, text: String, duration: float, token: int) -> void:
    if token != intro_token:
        return
    intro_title.text = title
    intro_text.text = text
    intro_title.modulate.a = 0.0
    intro_text.modulate.a = 0.0
    var appear := create_tween().set_parallel(true)
    appear.tween_property(intro_title, "modulate:a", 1.0, 0.45)
    appear.tween_property(intro_text, "modulate:a", 1.0, 0.65).set_delay(0.15)
    await appear.finished
    await get_tree().create_timer(duration).timeout
    if token != intro_token:
        return
    var disappear := create_tween().set_parallel(true)
    disappear.tween_property(intro_title, "modulate:a", 0.0, 0.35)
    disappear.tween_property(intro_text, "modulate:a", 0.0, 0.35)
    await disappear.finished

func _on_skip_pressed() -> void:
    if not intro_running:
        return
    intro_token += 1
    await _start_game()

func _start_game() -> void:
    await _fade_to_black(0.55)
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_controls_pressed() -> void:
    main_menu.visible = false
    controls_panel.visible = true
    $ControlsPanel/Panel/BackButton.grab_focus()

func _on_back_pressed() -> void:
    controls_panel.visible = false
    main_menu.visible = true
    $MainMenu/MenuBox/ControlsButton.grab_focus()

func _on_exit_pressed() -> void:
    get_tree().quit()

func _fade_to_black(duration: float) -> void:
    fade.mouse_filter = Control.MOUSE_FILTER_STOP
    var tween := create_tween()
    tween.tween_property(fade, "modulate:a", 1.0, duration)
    await tween.finished

func _fade_from_black(duration: float) -> void:
    var tween := create_tween()
    tween.tween_property(fade, "modulate:a", 0.0, duration)
    await tween.finished
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
