extends Control

const SurvivalMode = preload("res://src/modes/survival.gd")

enum Mode { NONE, HOST, JOIN }

var current_mode: int = Mode.NONE

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var ip_label: Label = $VBoxContainer/IpLabel
@onready var ip_input: LineEdit = $VBoxContainer/IpInput
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.pressed.connect(_on_start_pressed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	_input_connect_state(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input_connect_state(visible: bool) -> void:
	ip_label.visible = visible
	ip_input.visible = visible
	start_button.visible = visible


func _on_host_pressed() -> void:
	current_mode = Mode.HOST
	_input_connect_state(false)
	status_label.text = "Hosting..."
	NetworkManager.host_game()
	_start_game()


func _on_join_pressed() -> void:
	current_mode = Mode.JOIN
	_input_connect_state(true)
	ip_input.grab_focus()
	status_label.text = "Enter host IP address"


func _on_start_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Please enter an IP address"
		return
	current_mode = Mode.JOIN
	status_label.text = "Connecting..."
	start_button.disabled = true
	NetworkManager.connection_failed.disconnect(_on_connection_failed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.join_game(ip)
	_start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed"
	start_button.disabled = false
	NetworkManager.leave_game()


func _on_server_disconnected() -> void:
	status_label.text = "Disconnected"
	var game := get_node_or_null("/root/SurvivalMode")
	if game:
		game.queue_free()
	show()


func _start_game() -> void:
	var game := SurvivalMode.new()
	game.name = "SurvivalMode"
	get_tree().root.add_child(game, true)
	hide()
