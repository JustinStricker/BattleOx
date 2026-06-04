extends Control

const SurvivalMode = preload("res://src/modes/survival.gd")

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_play_pressed() -> void:
	var game: Node = SurvivalMode.new()
	get_parent().add_child(game)
	queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()
