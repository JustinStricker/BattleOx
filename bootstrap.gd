extends Node3D

const MainMenuScene = preload("res://main_menu.tscn")

func _ready() -> void:
	add_child(MainMenuScene.instantiate())
