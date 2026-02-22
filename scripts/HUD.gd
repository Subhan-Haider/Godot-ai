extends Control

@onready var hp_label = $VBox/HealthLabel
@onready var score_label = $VBox/ScoreLabel

func _ready():
	Global.health_changed.connect(_on_health_changed)
	Global.score_changed.connect(_on_score_changed)
	Global.game_over.connect(_on_game_over)
	
	# Initial update
	_on_health_changed(Global.player_hp)
	_on_score_changed(Global.score)

func _on_health_changed(val: int):
	hp_label.text = "HP: " + str(val)
	if val < 30:
		hp_label.add_theme_color_override("font_color", Color.RED)
	else:
		hp_label.add_theme_color_override("font_color", Color.WHITE)

func _on_score_changed(val: int):
	score_label.text = "Essence: " + str(val)

func _on_game_over():
	var label = Label.new()
	label.text = "VOID CONSUMED YOU\nFinal Essence: " + str(Global.score)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme_override_font_sizes.font_size = 48
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
	get_tree().paused = true
