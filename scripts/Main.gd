extends Node2D

var lives = 5
var score = 0
var spawn_timer = 0.0
var spawn_interval = 1.5

@onready var score_label = $CanvasLayer/ScoreLabel
@onready var lives_label = $CanvasLayer/LivesLabel
@onready var jump_scare_layer = $CanvasLayer/JumpScare

func _ready():
	RandomNumberGenerator.new()
	update_ui()
	jump_scare_layer.visible = false

var global_speed_multiplier = 1.0

func _process(delta):
	if lives <= 0:
		return
	
	# Slowly increase speed over time
	global_speed_multiplier += delta * 0.02
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_spider()
		spawn_timer = 0.0
		# Slightly speed up spawning over time
		spawn_interval = max(0.5, spawn_interval * 0.99)

func spawn_spider():
	var spider_scene = load("res://scenes/Spider.tscn")
	var spider = spider_scene.instantiate()
	
	# Pass the current speed multiplier to the spider
	if spider.has_method("set_multiplier"):
		spider.set_multiplier(global_speed_multiplier)
	
	# Random X position
	spider.position = Vector2(randf_range(50, 1100), -50)
	add_child(spider)

func spider_escaped():
	lives -= 1
	update_ui()
	if lives <= 0:
		trigger_jump_scare()

func shoot_spider(spider):
	score += 10
	update_ui()
	
	# Play squelch sound
	if has_node("SquelchSound"):
		get_node("SquelchSound").play()
		
	spider.hit()

func update_ui():
	score_label.text = "Tokens: " + str(score)
	lives_label.text = "Lives: " + str(lives)

func trigger_jump_scare():
	jump_scare_layer.visible = true
	
	# Play scream sound
	if has_node("ScreamSound"):
		get_node("ScreamSound").play()
	# Play scary sound here
	# get_tree().paused = true # Optional: pause game

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# In a real game, we'd use a raycast or check overlap
		# For this simple version, we'll check which spider was clicked
		for child in get_children():
			if child is Area2D and child.has_method("hit"):
				# This is a simplification. In a real Godot scene, 
				# we'd use the event position and check area bounds.
				if child.get_node("CollisionShape2D").shape.get_rect().has_point(event.position - child.position):
					shoot_spider(child)
					break
