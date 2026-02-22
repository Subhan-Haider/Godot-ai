extends CharacterBody2D

## Neon Velocity: Data Protocol - Player Controller
## Features: Gravity, Jump, Double-Jump, and Collision detection.

@export var JUMP_VELOCITY: float = -600.0
@export var DOUBLE_JUMP_VELOCITY: float = -500.0

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_count: int = 0
var max_jumps: int = 2

@onready var sprite: ColorRect = $Visuals

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_on_floor() or jump_count < max_jumps:
			jump()

	move_and_slide()
	
	# Check for collisions with obstacles
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("obstacles"):
			die()

func jump() -> void:
	if jump_count == 0:
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = DOUBLE_JUMP_VELOCITY
		
	jump_count += 1
	_pulse_effect()

func _pulse_effect() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func die() -> void:
	if GameManager.is_game_active:
		GameManager.trigger_game_over()
		queue_free()
