extends CharacterBody2D

@export var speed: float = 150.0
@export var health: int = 30
@export var damage: int = 5

@onready var sprite = $Sprite2D
var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if player:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * speed
		move_and_slide()
		look_at(player.global_position)

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		die()
	else:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.PURPLE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func die():
	Global.score += 100
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
