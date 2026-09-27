extends Area2D

const REGULAR_SPRITE := preload("res://assets/spider_regular.png")
const RUNNER_SPRITE := preload("res://assets/spider_runner.png")

var speed := 92.0
var speed_multiplier := 1.0
var escaped := false
var is_runner := false
var score_value := 10


func configure_runner() -> void:
	is_runner = true
	speed = 148.0
	score_value = 25
	scale = Vector2(0.76, 0.76)


func get_hit_radius() -> float:
	return 24.0 * maxf(scale.x, scale.y)


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	position.y += speed * speed_multiplier * delta
	rotation = sin(Time.get_ticks_msec() * 0.005 + position.x) * 0.045
	if position.y >= 540.0 and not escaped:
		escaped = true
		get_parent().spider_escaped()
		queue_free()


func hit() -> void:
	queue_free()


func _draw() -> void:
	var silk_color := Color(0.76, 0.68, 0.82, 0.42)
	draw_line(Vector2(0, -12), Vector2(0, -maxf(position.y + 12.0, 12.0)), silk_color, 1.2, true)
	var sprite := RUNNER_SPRITE if is_runner else REGULAR_SPRITE
	draw_texture_rect(sprite, Rect2(Vector2(-34, -34), Vector2(68, 68)), false)
