@tool
extends Node

## Neon Velocity: Data Protocol - Global Manager
## Handles scoring, game state, and difficulty scaling.

signal score_changed(new_score: int)
signal level_speed_changed(new_speed: float)
signal game_over

const INITIAL_SPEED: float = 400.0
const SPEED_INCREMENT: float = 10.0
const MAX_SPEED: float = 1200.0

var current_score: int = 0
var current_speed: float = INITIAL_SPEED
var is_game_active: bool = false

func _ready() -> void:
	reset_game()

func reset_game() -> void:
	current_score = 0
	current_speed = INITIAL_SPEED
	is_game_active = true
	score_changed.emit(current_score)
	level_speed_changed.emit(current_speed)

func add_score(amount: int) -> void:
	current_score += amount
	score_changed.emit(current_score)
	
	# Increase speed every 10 points
	if current_score % 10 == 0:
		increase_speed()

func increase_speed() -> void:
	current_speed = clamp(current_speed + SPEED_INCREMENT, INITIAL_SPEED, MAX_SPEED)
	level_speed_changed.emit(current_speed)

func trigger_game_over() -> void:
	is_game_active = false
	game_over.emit()
