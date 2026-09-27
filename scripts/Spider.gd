extends Area2D

var speed = 100.0
var color = Color.WHITE

var speed_multiplier = 1.0

func _ready():
	# Randomize color for that "neon" look
	var colors = [Color.MAGENTA, Color.CYAN, Color.LIME, Color.YELLOW]
	color = colors[randi() % colors.size()]
	modulate = color

func set_multiplier(m):
	speed_multiplier = m

func _process(delta):
	position.y += speed * speed_multiplier * delta
	
	# If spider goes off screen, notify main
	if position.y > 700:
		get_parent().spider_escaped()
		queue_free()

func hit():
	# Add juice: maybe a small particle effect here later
	queue_free()
