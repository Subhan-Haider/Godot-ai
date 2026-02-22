extends CharacterBody2D

@export var speed: float = 300.0
@export var bullet_scene: PackedScene = preload("res://scenes/Projectile.tscn")

@onready var sprite = $Sprite2D
@onready var muzzle = $Muzzle

func _physics_process(_delta: float) -> void:
	# Movement
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	# Aiming (Look at Mouse)
	look_at(get_global_mouse_position())
	
	# Shooting
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shoot()

func shoot():
	if bullet_scene:
		var b = bullet_scene.instantiate()
		b.global_position = muzzle.global_position
		b.global_rotation = global_rotation
		get_parent().add_child(b)

func take_damage(amount: int):
	Global.player_hp -= amount
	# Visual feedback (flash red)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
