extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
@export var spawn_radius: float = 600.0
@export var spawn_interval: float = 2.0

@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.wait_time = spawn_interval
	timer.timeout.connect(_on_spawn_timer)
	timer.start()
	
	# Initial spawn
	for i in range(5):
		_on_spawn_timer()

func _on_spawn_timer():
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		var spawn_pos = Vector2.RIGHT.rotated(randf() * TAU) * (spawn_radius + randf() * 200)
		enemy.global_position = spawn_pos
		add_child(enemy)
		
		# Increase difficulty over time
		timer.wait_time = max(0.5, spawn_interval - (Global.score / 5000.0))
