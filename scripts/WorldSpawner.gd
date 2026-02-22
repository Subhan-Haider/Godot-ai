extends Node2D

## Neon Velocity: Data Protocol - Spawner System
## Responsibilities: Infinite floor generation and obstacle placement.

@export var OBSTACLE_SCENE: PackedScene
@export var FLOOR_SCENE: PackedScene

var spawn_timer: float = 0.0
var spawn_interval: float = 1.5 # Seconds between obstacles

func _process(delta: float) -> void:
	if not GameManager.is_game_active: return
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		_spawn_obstacle()
		spawn_timer = 0.0
		# Randomize next interval slightly
		spawn_interval = randf_range(0.8, 2.0)

func _spawn_obstacle() -> void:
	# Note: In a real project, we would preload these. 
	# For the demo, we'll create a simple ColorRect obstacle if the scene isn't assigned.
	var obstacle = StaticBody2D.new()
	obstacle.add_to_group("obstacles")
	obstacle.position = Vector2(1200, 500) # Spawn off-screen to the right
	
	var visual = ColorRect.new()
	visual.size = Vector2(40, 60)
	visual.color = Color(1, 0, 0.4) # Cyberpunk Pink
	obstacle.add_child(visual)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = visual.size
	collision.shape = shape
	collision.position = visual.size / 2
	obstacle.add_child(collision)
	
	add_child(obstacle)
	
	# Logic to move the obstacle left
	var move_script = "extends StaticBody2D\nfunc _process(delta):\n\tposition.x -= GameManager.current_speed * delta\n\tif position.x < -100:\n\t\tif GameManager.is_game_active: GameManager.add_score(1)\n\t\tqueue_free()"
	var script = GDScript.new()
	script.source_code = move_script
	script.reload()
	obstacle.set_script(script)
