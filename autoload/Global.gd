extends Node

# Global Game State for Void Crawler
signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal game_over

var score: int = 0:
	set(val):
		score = val
		score_changed.emit(score)

var player_hp: int = 100:
	set(val):
		player_hp = clampi(val, 0, 100)
		health_changed.emit(player_hp)
		if player_hp <= 0:
			game_over.emit()

var void_essence: int = 0
var current_level: int = 1

func reset_game():
	score = 0
	player_hp = 100
	void_essence = 0
	current_level = 1
