extends Area2D

const REGULAR_SPRITE := preload("res://assets/spider_regular.png")
const RUNNER_SPRITE := preload("res://assets/spider_runner.png")

var speed := 92.0
var speed_multiplier := 1.0
var escaped := false
var is_runner := false
var is_bug := false
var kind := "spider"
var score_value := 10
var skitter_amp := 0.0
var skitter_freq := 1.0
var skitter_phase := 0.0
var body_jitter := 1.0


func configure_runner() -> void:
	is_runner = true
	kind = "runner"
	speed = 148.0
	score_value = 25
	scale = Vector2(0.76, 0.76)


func configure_bug_spider() -> void:
	is_bug = true
	kind = "bug-spider"
	speed = 168.0
	score_value = 8
	skitter_amp = randf_range(90.0, 160.0)
	skitter_freq = randf_range(8.0, 14.0)
	skitter_phase = randf() * TAU
	body_jitter = randf_range(0.86, 1.16)


func get_hit_radius() -> float:
	if is_bug:
		return 20.0
	return 24.0 * maxf(scale.x, scale.y)


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if is_bug:
		var sway := sin(skitter_phase + Time.get_ticks_msec() * 0.001 * skitter_freq) * skitter_amp
		position.x = clampf(position.x + sway * delta, 28.0, 1124.0)
	position.y += speed * speed_multiplier * delta
	var wobble := 0.24 if is_bug else 0.045
	rotation = sin(Time.get_ticks_msec() * 0.005 + position.x) * wobble
	if position.y >= 540.0 and not escaped:
		escaped = true
		_notify_bug(false)
		get_parent().spider_escaped()
		queue_free()


func hit() -> void:
	_notify_bug(true)
	queue_free()


func _notify_bug(killed: bool) -> void:
	if not is_bug:
		return
	var parent := get_parent()
	if parent != null and parent.has_method("notify_bug_outcome"):
		parent.notify_bug_outcome(killed)


func _draw() -> void:
	if is_bug:
		_draw_bug_spider()
		return
	var silk_color := Color(0.76, 0.68, 0.82, 0.42)
	draw_line(Vector2(0, -12), Vector2(0, -maxf(position.y + 12.0, 12.0)), silk_color, 1.2, true)
	var sprite := RUNNER_SPRITE if is_runner else REGULAR_SPRITE
	draw_texture_rect(sprite, Rect2(Vector2(-34, -34), Vector2(68, 68)), false)


func _draw_bug_spider() -> void:
	var tick := float(Time.get_ticks_msec()) * 0.001
	var leg_wave := sin(tick * skitter_freq * 1.8 + skitter_phase)
	draw_line(Vector2(0, -8), Vector2(0, -maxf(position.y * 0.4, 18.0)), Color(1.0, 0.45, 0.82, 0.3), 1.0, true)
	for i in range(8):
		var side := -1.0 if i < 4 else 1.0
		var row := i % 4
		var origin := Vector2(side * 5.0, -8.0 + float(row) * 5.5)
		var kick := leg_wave * side * (1.0 if row % 2 == 0 else -1.0)
		var tip := origin + Vector2(side * (16.0 + float(row) * 1.6), 7.0 + kick * 5.0)
		draw_line(origin, tip, Color(1.0, 0.62, 0.86), 1.5, true)
	var twitch := sin(tick * 22.0) * 3.0
	draw_line(Vector2(-3, -9), Vector2(-9, -18 + twitch), Color(1.0, 0.78, 0.92), 1.2, true)
	draw_line(Vector2(3, -9), Vector2(9, -18 - twitch), Color(1.0, 0.78, 0.92), 1.2, true)
	draw_circle(Vector2(0, 2), 10.0 * body_jitter, Color(0.42, 0.02, 0.22, 1))
	draw_circle(Vector2(0, -3), 7.4 * body_jitter, Color(0.98, 0.16, 0.58, 1))
	draw_circle(Vector2(-2.3, -6.4), 2.5, Color(0.2, 1.0, 0.86, 1))
	draw_circle(Vector2(2.3, -6.4), 2.5, Color(0.2, 1.0, 0.86, 1))
	draw_circle(Vector2(-2.3, -6.4), 1.05, Color(0.02, 0.04, 0.05, 1))
	draw_circle(Vector2(2.3, -6.4), 1.05, Color(0.02, 0.04, 0.05, 1))
