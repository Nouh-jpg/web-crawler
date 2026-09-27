extends Node2D

const VIEW_SIZE := Vector2(1152.0, 648.0)
const HOUSE_HEALTH := 10
const FLOOR_Y := 540.0
const GUN_ORIGIN := Vector2(576.0, 604.0)
const BULLET_SPEED := 940.0
const REVOLVER_CAPACITY := 6
const SPIDER_SCENE := preload("res://scenes/Spider.tscn")
const ROOM_BACKGROUND := preload("res://assets/room_background.png")
const GUN_ART := [
	preload("res://assets/gun_revolver_hand.png"),
	preload("res://assets/gun_pistol_hand.png"),
	preload("res://assets/gun_shotgun_hand.png")
]
const KILL_PHRASES := ["FIVE DOWN!", "NICE SHOOTIN'!", "WEB-SLINGIN'!", "BUG OFF!", "KEEP 'EM CRAWLIN'!"]
const WEAPON_NAMES := ["REVOLVER", "PISTOL", "SHOTGUN"]
const WEAPON_CAPACITIES := [6, 12, 2]
const WEAPON_RELOADS := [1.05, 1.2, 1.5]
const WEAPON_INTERVALS := [0.32, 0.19, 0.58]
const WEAPON_RECOIL_DURATIONS := [0.2, 0.1, 0.32]
const WEAPON_RECOIL_STRENGTHS := [23.0, 11.0, 43.0]
const WEAPON_RECOIL_TWISTS := [0.075, 0.035, 0.18]
const WEAPON_FLASH_DURATIONS := [0.09, 0.055, 0.15]
const WEAPON_COST_BASE := 4
const WEAPON_MAX_LEVEL := 3

var house_health := HOUSE_HEALTH
var score := 0
var spiders_shot := 0
var runner_ever_seen := false
var weapon_parts := 0
var selected_weapon := 0
var weapon_levels: Array[int] = [0, 0, 0]
var weapon_ammo: Array[int] = [6, 12, 2]
var weapon_reload_timers: Array[float] = [0.0, 0.0, 0.0]
var ammo := REVOLVER_CAPACITY
var elapsed_time := 0.0
var spawn_timer := 0.0
var fire_timer := 0.0
var reload_timer := 0.0
var recoil_timer := 0.0
var muzzle_flash_timer := 0.0
var phrase_timer := 0.0
var phrase_index := 0
var shell_casings: Array[Dictionary] = []
var hit_sparks: Array[Dictionary] = []
var breach_flash := 0.0
var game_over := false
var bullets: Array[Dictionary] = []
var mouse_is_down := false
var touch_is_down := false
var aim_position := Vector2(576.0, 300.0)
var random_source := RandomNumberGenerator.new()

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var lives_label: Label = $CanvasLayer/LivesLabel
@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var phrase_label: Label = $CanvasLayer/PhraseLabel
@onready var parts_label: Label = $CanvasLayer/PartsLabel
@onready var upgrade_button: Button = $CanvasLayer/UpgradeButton
@onready var weapon_buttons: Array[Button] = [
	$CanvasLayer/RevolverButton,
	$CanvasLayer/PistolButton,
	$CanvasLayer/ShotgunButton
]
@onready var jump_scare_layer: Control = $CanvasLayer/JumpScare
@onready var lady_sprite: TextureRect = $CanvasLayer/JumpScare/ScaryLady
@onready var flash_layer: ColorRect = $CanvasLayer/JumpScare/Flash
@onready var game_over_label: Label = $CanvasLayer/JumpScare/GameOverLabel
@onready var restart_button: Button = $CanvasLayer/JumpScare/RestartButton
@onready var music_player: AudioStreamPlayer = $Music
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var weapon_sounds: Array[AudioStreamPlayer] = [
	$RevolverShot,
	$PistolShot,
	$ShotgunShot
]


func _ready() -> void:
	random_source.randomize()
	jump_scare_layer.visible = false
	phrase_label.visible = false
	restart_button.pressed.connect(_restart_game)
	music_player.finished.connect(_loop_music)
	music_player.play()
	for index in range(weapon_buttons.size()):
		weapon_buttons[index].pressed.connect(_select_weapon.bind(index))
	upgrade_button.pressed.connect(_upgrade_selected_weapon)
	update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return

	elapsed_time += delta
	fire_timer = maxf(fire_timer - delta, 0.0)
	recoil_timer = maxf(recoil_timer - delta, 0.0)
	muzzle_flash_timer = maxf(muzzle_flash_timer - delta, 0.0)
	phrase_timer = maxf(phrase_timer - delta, 0.0)
	spawn_timer += delta
	breach_flash = maxf(breach_flash - delta, 0.0)
	_update_casings(delta)
	_update_hit_sparks(delta)
	if reload_timer > 0.0:
		reload_timer = maxf(reload_timer - delta, 0.0)
		ammo_label.text = "RELOADING  %0.1fs" % reload_timer
		weapon_reload_timers[selected_weapon] = reload_timer
		if reload_timer == 0.0:
			ammo = _weapon_capacity(selected_weapon)
			weapon_ammo[selected_weapon] = ammo
			weapon_reload_timers[selected_weapon] = 0.0
			update_ui()
	phrase_label.visible = phrase_timer > 0.0
	phrase_label.modulate.a = minf(phrase_timer * 3.0, 1.0)
	phrase_label.scale = Vector2.ONE * (1.0 + maxf(phrase_timer - 1.8, 0.0) * 0.16)

	var current_spawn_interval := maxf(0.48, 1.45 - elapsed_time * 0.006)
	if spawn_timer >= current_spawn_interval:
		spawn_timer -= current_spawn_interval
		spawn_spider()

	if (mouse_is_down or touch_is_down) and fire_timer <= 0.0:
		fire_bullet()

	update_bullets(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_is_down = event.pressed
		aim_position = event.position
		if event.pressed and fire_timer <= 0.0:
			fire_bullet()
	elif event is InputEventScreenTouch:
		touch_is_down = event.pressed
		aim_position = event.position
		if event.pressed and fire_timer <= 0.0:
			fire_bullet()
	elif event is InputEventScreenDrag:
		aim_position = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_start_reload()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_select_weapon(0)
		elif event.keycode == KEY_2:
			_select_weapon(1)
		elif event.keycode == KEY_3:
			_select_weapon(2)
		elif event.keycode == KEY_U:
			_upgrade_selected_weapon()


func spawn_spider() -> void:
	var spider := SPIDER_SCENE.instantiate() as Area2D
	var progress_speed := minf(1.0 + elapsed_time * 0.009, 3.2)
	spider.position = Vector2(random_source.randf_range(48.0, VIEW_SIZE.x - 48.0), -35.0)
	spider.set("speed_multiplier", progress_speed)
	var runner_chance := minf(0.10 + maxf(elapsed_time - 15.0, 0.0) * 0.0015, 0.24)
	if elapsed_time >= 15.0 and random_source.randf() < runner_chance:
		spider.configure_runner()
		if not runner_ever_seen:
			runner_ever_seen = true
			_show_notice("RUNNER! FAST, BUT WORTH 25")
	add_child(spider)


func fire_bullet() -> void:
	if game_over or reload_timer > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	var direction := _aim_direction()
	var pellet_count := 1
	var bullet_speed := BULLET_SPEED
	var bullet_color := Color("ffc95c")
	match selected_weapon:
		1:
			bullet_speed = 1120.0
			bullet_color = Color("d5edf2")
		2:
			pellet_count = 5 + weapon_levels[2] * 2
			bullet_speed = 760.0
			bullet_color = Color("ff9e58")
	var muzzle_distance := 14.0
	for pellet in range(pellet_count):
		var shot_direction := direction
		if selected_weapon == 2:
			var spread_step := TAU * 0.018 * (float(pellet) - float(pellet_count - 1) * 0.5)
			shot_direction = direction.rotated(spread_step)
		var barrel_tip := GUN_ORIGIN + shot_direction * muzzle_distance
		bullets.append({"position": barrel_tip, "velocity": shot_direction * bullet_speed, "life": 1.2, "color": bullet_color})
	ammo -= 1
	weapon_ammo[selected_weapon] = ammo
	fire_timer = _weapon_interval(selected_weapon)
	recoil_timer = WEAPON_RECOIL_DURATIONS[selected_weapon]
	muzzle_flash_timer = WEAPON_FLASH_DURATIONS[selected_weapon]
	weapon_sounds[selected_weapon].play()
	if selected_weapon != 0:
		_add_shell_casing()
	update_ui()
	if ammo == 0:
		_start_reload()
	queue_redraw()


func update_bullets(delta: float) -> void:
	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[bullet_index]
		bullet.position += bullet.velocity * delta
		bullet.life -= delta
		var bullet_hit := false

		for spider in get_children():
			if spider is Area2D and spider.has_method("hit") and not spider.is_queued_for_deletion():
				var hit_radius: float = spider.get_hit_radius() + 5.0 if spider.has_method("get_hit_radius") else 29.0
				if bullet.position.distance_to(spider.position) <= hit_radius:
					shoot_spider(spider)
					bullet_hit = true
					break

		if bullet_hit or bullet.life <= 0.0 or bullet.position.y < -40.0 or bullet.position.x < -40.0 or bullet.position.x > VIEW_SIZE.x + 40.0:
			bullets.remove_at(bullet_index)
		else:
			bullets[bullet_index] = bullet


func spider_escaped() -> void:
	if game_over:
		return
	house_health = maxi(house_health - 1, 0)
	breach_flash = 0.22
	update_ui()
	if house_health == 0:
		trigger_jump_scare()


func shoot_spider(spider: Area2D) -> void:
	if game_over:
		return
	var kill_value := int(spider.get("score_value"))
	score += kill_value
	weapon_parts += 2 if kill_value > 10 else 1
	spiders_shot += 1
	hit_sparks.append({"position": spider.position, "life": 0.22})
	if spiders_shot % 5 == 0:
		score += 25
		_show_kill_phrase()
	update_ui()
	if has_node("SquelchSound"):
		$SquelchSound.play()
	spider.hit()


func update_ui() -> void:
	score_label.text = "SCORE  %05d" % score
	lives_label.text = "HOUSE  %02d / %02d" % [house_health, HOUSE_HEALTH]
	lives_label.add_theme_color_override("font_color", Color("ff5d65") if house_health <= 3 else Color("f4e6c9"))
	if reload_timer > 0.0:
		ammo_label.text = "RELOADING  %0.1fs" % reload_timer
	else:
		ammo_label.text = "%s  %d / %d" % [WEAPON_NAMES[selected_weapon], ammo, _weapon_capacity(selected_weapon)]
		ammo_label.add_theme_color_override("font_color", Color("ff696d") if ammo <= 2 else Color("ffc95c"))
	parts_label.text = "PARTS  %02d" % weapon_parts
	_update_weapon_controls()


func _start_reload() -> void:
	if game_over or reload_timer > 0.0 or ammo >= _weapon_capacity(selected_weapon):
		return
	reload_timer = _weapon_reload_duration(selected_weapon)
	weapon_reload_timers[selected_weapon] = reload_timer
	reload_sound.play()
	update_ui()


func _select_weapon(index: int) -> void:
	if game_over or index < 0 or index >= WEAPON_NAMES.size() or index == selected_weapon:
		return
	weapon_ammo[selected_weapon] = ammo
	weapon_reload_timers[selected_weapon] = reload_timer
	selected_weapon = index
	ammo = mini(weapon_ammo[selected_weapon], _weapon_capacity(selected_weapon))
	reload_timer = weapon_reload_timers[selected_weapon]
	fire_timer = 0.0
	update_ui()
	queue_redraw()


func _upgrade_selected_weapon() -> void:
	var level := weapon_levels[selected_weapon]
	if game_over or level >= WEAPON_MAX_LEVEL:
		return
	var cost := WEAPON_COST_BASE + level * 4
	if weapon_parts < cost:
		return
	weapon_parts -= cost
	weapon_levels[selected_weapon] += 1
	reload_timer = 0.0
	weapon_reload_timers[selected_weapon] = 0.0
	ammo = _weapon_capacity(selected_weapon)
	weapon_ammo[selected_weapon] = ammo
	update_ui()
	queue_redraw()


func _update_weapon_controls() -> void:
	for index in range(weapon_buttons.size()):
		var level := weapon_levels[index]
		weapon_buttons[index].text = "%s%s\nLV %d" % ["▶ " if index == selected_weapon else "", WEAPON_NAMES[index], level]
		weapon_buttons[index].disabled = game_over
	var level := weapon_levels[selected_weapon]
	var cost := WEAPON_COST_BASE + level * 4
	if level >= WEAPON_MAX_LEVEL:
		upgrade_button.text = "MAX UPGRADE"
		upgrade_button.disabled = true
	else:
		var effect := "+2 PELLETS · +1 SHELL" if selected_weapon == 2 else ("+4 ROUNDS · FASTER" if selected_weapon == 1 else "+2 ROUNDS · FASTER")
		upgrade_button.text = "UPGRADE %s · %d PARTS\n%s" % [WEAPON_NAMES[selected_weapon], cost, effect]
		upgrade_button.disabled = game_over or weapon_parts < cost


func _weapon_capacity(index: int) -> int:
	var level := weapon_levels[index]
	if index == 0:
		return WEAPON_CAPACITIES[index] + level * 2
	if index == 1:
		return WEAPON_CAPACITIES[index] + level * 4
	return WEAPON_CAPACITIES[index] + level


func _weapon_interval(index: int) -> float:
	return WEAPON_INTERVALS[index] * pow(0.92, weapon_levels[index])


func _weapon_reload_duration(index: int) -> float:
	return WEAPON_RELOADS[index] * pow(0.9, weapon_levels[index])


func _show_kill_phrase() -> void:
	_show_notice("%s   +25" % KILL_PHRASES[phrase_index % KILL_PHRASES.size()])
	phrase_index += 1


func _show_notice(message: String) -> void:
	phrase_label.text = message
	phrase_timer = 2.1
	phrase_label.visible = true
	phrase_label.modulate.a = 1.0
	phrase_label.scale = Vector2(0.75, 0.75)


func _add_shell_casing() -> void:
	var direction := _aim_direction()
	var side := Vector2(-direction.y, direction.x)
	shell_casings.append({
		"position": GUN_ORIGIN + side * 18.0,
		"velocity": side * random_source.randf_range(100.0, 180.0) + Vector2(0.0, -random_source.randf_range(45.0, 110.0)),
		"life": 0.7,
		"rotation": random_source.randf_range(-0.7, 0.7),
		"half_width": 4.5 if selected_weapon == 2 else 3.0,
		"half_length": 8.0 if selected_weapon == 2 else 6.0,
		"color": Color("c8524e") if selected_weapon == 2 else Color("e3b75e")
	})


func _update_casings(delta: float) -> void:
	for i in range(shell_casings.size() - 1, -1, -1):
		var casing: Dictionary = shell_casings[i]
		casing.position += casing.velocity * delta
		casing.velocity.y += 340.0 * delta
		casing.rotation += delta * 8.0
		casing.life -= delta
		if casing.life <= 0.0:
			shell_casings.remove_at(i)
		else:
			shell_casings[i] = casing


func _update_hit_sparks(delta: float) -> void:
	for i in range(hit_sparks.size() - 1, -1, -1):
		hit_sparks[i].life -= delta
		if hit_sparks[i].life <= 0.0:
			hit_sparks.remove_at(i)


func _aim_direction() -> Vector2:
	var direction := (aim_position - GUN_ORIGIN).normalized()
	if direction.y > -0.08:
		direction = Vector2(direction.x, -0.35).normalized()
	return direction


func trigger_jump_scare() -> void:
	game_over = true
	mouse_is_down = false
	touch_is_down = false
	bullets.clear()
	jump_scare_layer.visible = true
	game_over_label.visible = false
	restart_button.visible = false
	lady_sprite.scale = Vector2(0.72, 0.72)
	flash_layer.color = Color(1.0, 1.0, 1.0, 1.0)
	var scare_tween := create_tween()
	scare_tween.tween_property(flash_layer, "color", Color(0.65, 0.015, 0.04, 0.92), 0.08)
	scare_tween.tween_property(flash_layer, "color", Color(0.015, 0.008, 0.02, 0.12), 0.12)
	scare_tween.tween_property(lady_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scare_tween.tween_interval(0.28)
	scare_tween.tween_callback(_reveal_game_over)
	if has_node("ScreamSound"):
		$ScreamSound.play()


func _reveal_game_over() -> void:
	game_over_label.visible = true
	restart_button.visible = true


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _loop_music() -> void:
	if not game_over:
		music_player.play()


func _draw() -> void:
	draw_texture_rect(ROOM_BACKGROUND, Rect2(Vector2.ZERO, VIEW_SIZE), false)
	_draw_bullets()
	_draw_hit_sparks()
	_draw_shell_casings()
	_draw_gun()
	_draw_crosshair()
	if breach_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 0.04, 0.06, breach_flash * 0.55))

func _draw_bullets() -> void:
	for bullet in bullets:
		var position: Vector2 = bullet.position
		var color: Color = bullet.color
		var direction: Vector2 = bullet.velocity.normalized()
		draw_line(position - direction * 9.0, position + direction * 7.0, color, 4.0)
		draw_circle(position, 2.5, Color.WHITE)


func _draw_hit_sparks() -> void:
	for spark in hit_sparks:
		var alpha := clampf(spark.life / 0.22, 0.0, 1.0)
		var position: Vector2 = spark.position
		draw_arc(position, 24.0 * (1.0 - alpha) + 6.0, 0.0, TAU, 20, Color(0.42, 0.92, 1.0, alpha), 3.0)
		for angle in range(0, 360, 60):
			var ray := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
			draw_line(position + ray * 9.0, position + ray * (18.0 + 8.0 * (1.0 - alpha)), Color(1.0, 0.83, 0.43, alpha), 2.0)


func _draw_shell_casings() -> void:
	for casing in shell_casings:
		var position: Vector2 = casing.position
		var rotation: float = casing.rotation
		var half_width: float = casing.half_width
		var half_length: float = casing.half_length
		var shape := PackedVector2Array([
			position + Vector2(-half_width, -half_length).rotated(rotation),
			position + Vector2(half_width, -half_length).rotated(rotation),
			position + Vector2(half_width, half_length).rotated(rotation),
			position + Vector2(-half_width, half_length).rotated(rotation)
		])
		draw_colored_polygon(shape, casing.color)


func _draw_gun() -> void:
	var direction := _aim_direction()
	var gun_height: float = [214.0, 200.0, 232.0][selected_weapon]
	var gun_width := gun_height * 1024.0 / 1536.0
	var art: Texture2D = GUN_ART[selected_weapon]
	var recoil_progress: float = clampf(recoil_timer / WEAPON_RECOIL_DURATIONS[selected_weapon], 0.0, 1.0)
	var recoil_kick: float = WEAPON_RECOIL_STRENGTHS[selected_weapon] * pow(recoil_progress, 1.6)
	var reload_duration: float = _weapon_reload_duration(selected_weapon)
	var reload_progress: float = 1.0 - reload_timer / reload_duration if reload_timer > 0.0 else 0.0
	var reload_motion: float = sin(clampf(reload_progress, 0.0, 1.0) * PI)
	var reload_drops := [12.0, 7.0, 24.0]
	var reload_turns := [0.2, 0.06, 0.48]
	var reload_drop: float = reload_drops[selected_weapon] * reload_motion
	var reload_turn: float = reload_turns[selected_weapon] * reload_motion
	var recoil_turn: float = WEAPON_RECOIL_TWISTS[selected_weapon] * recoil_progress
	var base: Vector2 = GUN_ORIGIN - direction * recoil_kick + Vector2(0.0, reload_drop)
	draw_set_transform(base, direction.angle() + PI * 0.5 + reload_turn + recoil_turn, Vector2.ONE)
	draw_texture_rect(art, Rect2(Vector2(-gun_width * 0.5, -gun_height), Vector2(gun_width, gun_height)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var muzzle_offset := gun_height * 0.98
	var side := Vector2(-direction.y, direction.x)
	if selected_weapon == 2 and muzzle_flash_timer > 0.0:
		_draw_muzzle_flash(base + direction * muzzle_offset + side * 5.0, direction)
		_draw_muzzle_flash(base + direction * muzzle_offset - side * 5.0, direction)
	else:
		_draw_muzzle_flash(base + direction * muzzle_offset, direction)


func _draw_muzzle_flash(tip: Vector2, direction: Vector2) -> void:
	if muzzle_flash_timer <= 0.0:
		return
	var ray_count: int = [7, 5, 11][selected_weapon]
	var flash_scale: float = [0.9, 0.65, 1.5][selected_weapon]
	for ray in range(ray_count):
		var flash_direction := direction.rotated(TAU * float(ray) / float(ray_count))
		var start := tip + flash_direction * 4.0
		var finish := tip + flash_direction * (19.0 + float(ray % 3) * 5.0) * flash_scale
		draw_line(start, finish, Color("ffe276"), 3.0 * flash_scale, true)
	draw_circle(tip, 6.0 * flash_scale, Color("fff4bf"))


func _draw_crosshair() -> void:
	if game_over:
		return
	draw_arc(aim_position, 12.0, 0.0, TAU, 24, Color("ff696d"), 2.0)
	draw_line(aim_position + Vector2(-18, 0), aim_position + Vector2(-6, 0), Color("ff696d"), 2.0)
	draw_line(aim_position + Vector2(6, 0), aim_position + Vector2(18, 0), Color("ff696d"), 2.0)
	draw_line(aim_position + Vector2(0, -18), aim_position + Vector2(0, -6), Color("ff696d"), 2.0)
	draw_line(aim_position + Vector2(0, 6), aim_position + Vector2(0, 18), Color("ff696d"), 2.0)
