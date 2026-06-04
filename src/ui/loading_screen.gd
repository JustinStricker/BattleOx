extends CanvasLayer

@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

func _ready() -> void:
	progress_bar.value = 0.0

func update(phase_name: String, progress: float) -> void:
	message_label.text = phase_name
	var tween := create_tween()
	tween.tween_property(progress_bar, "value", progress, 0.15).set_ease(Tween.EASE_OUT)
