extends Node2D

const VIEW_SIZE := Vector2(1152.0, 648.0)
const HOUSE_HEALTH := 10
const FLOOR_Y := 540.0
const GUN_ORIGIN := Vector2(576.0, 604.0)
const BULLET_SPEED := 940.0
const REVOLVER_CAPACITY := 6
const SPIDER_SCENE := preload("res://scenes/Spider.tscn")
const COMBAT_FX_SCRIPT := preload("res://scripts/CombatFX.gd")
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
const MAP_TITLES := ["THE ATTIC", "THE CELLAR", "THE NURSERY", "THE NEST"]
const MAP_WAVE_MILESTONES := [1, 4, 8, 12]
const MAP_ACCENTS := [Color("f4e6c9"), Color("7dffb2"), Color("ff9ec4"), Color("e7a6ff")]
const BUG_WAVE_EVERY := 5

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
var muzzle_flash_timer := 0.0
var muzzle_smoke_timer := 0.0
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
var gun_aim_position := Vector2(576.0, 300.0)
var recoil_offset := 0.0
var recoil_velocity := 0.0
var sway_offset := 0.0
var random_source := RandomNumberGenerator.new()
var wave_number := 0
var wave_remaining_to_spawn := 0
var wave_break_timer := 1.25
var bug_wave_active := false
var bug_wave_spawned := 0
var bug_wave_killed := 0
var bug_wave_escaped := 0
var map_index := 0
var map_flash := 0.0
var reward_flash := 0.0
var nest_bonus_level := 0
var praised_weapon := -1
var praised_timer := 0.0
var combat_fx: Node2D
var lady_scream: AudioStreamPlayer

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
	gun_aim_position = aim_position
	_setup_combat_fx()
	_setup_lady_scream()
	update_ui()
	_show_notice("THE ATTIC", 1.2, _map_accent(0))
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return

	elapsed_time += delta
	fire_timer = maxf(fire_timer - delta, 0.0)
	muzzle_flash_timer = maxf(muzzle_flash_timer - delta, 0.0)
	muzzle_smoke_timer = maxf(muzzle_smoke_timer - delta, 0.0)
	phrase_timer = maxf(phrase_timer - delta, 0.0)
	breach_flash = maxf(breach_flash - delta, 0.0)
	map_flash = maxf(map_flash - delta * 1.15, 0.0)
	reward_flash = maxf(reward_flash - delta * 0.85, 0.0)
	_update_gun_motion(delta)
	_update_praise(delta)
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
	_advance_waves(delta)

	if (mouse_is_down or touch_is_down) and fire_timer <= 0.0:
		fire_bullet()

	update_bullets(delta)
	_update_wave_banner()
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
	spider.position = Vector2(_spawn_x(), -35.0)
	if bug_wave_active:
		spider.configure_bug_spider()
		spider.speed_multiplier = minf(1.08 + float(wave_number) * 0.02, 1.55)
		bug_wave_spawned += 1
	else:
		spider.speed_multiplier = minf(1.0 + elapsed_time * 0.009, 3.2)
		var runner_chance := minf(0.10 + maxf(elapsed_time - 15.0, 0.0) * 0.0015, 0.24)
		if elapsed_time >= 15.0 and random_source.randf() < runner_chance:
			spider.configure_runner()
			if not runner_ever_seen:
				runner_ever_seen = true
				_show_notice("RUNNER! FAST, BUT WORTH 25", 2.1, Color("7dffb2"))
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
	var trail := 1.0
	var girth := 1.0
	match selected_weapon:
		1:
			bullet_speed = 1120.0
			bullet_color = Color("d5edf2")
			trail = 1.2
			girth = 0.85
		2:
			pellet_count = 5 + weapon_levels[2] * 2
			bullet_speed = 760.0
			bullet_color = Color("ff9e58")
			trail = 0.62
			girth = 1.28
	var muzzle_distance := 14.0
	for pellet in range(pellet_count):
		var shot_direction := direction
		if selected_weapon == 2:
			var spread_step := TAU * 0.018 * (float(pellet) - float(pellet_count - 1) * 0.5)
			shot_direction = direction.rotated(spread_step)
		var barrel_tip := GUN_ORIGIN + shot_direction * muzzle_distance
		bullets.append({
			"position": barrel_tip,
			"velocity": shot_direction * bullet_speed,
			"life": 1.2,
			"color": bullet_color,
			"trail": trail,
			"girth": girth
		})
	ammo -= 1
	weapon_ammo[selected_weapon] = ammo
	fire_timer = _weapon_interval(selected_weapon)
	recoil_velocity += WEAPON_RECOIL_STRENGTHS[selected_weapon] * 14.0
	sway_offset += random_source.randf_range(-1.0, 1.0) * WEAPON_RECOIL_STRENGTHS[selected_weapon] * 0.08
	muzzle_flash_timer = WEAPON_FLASH_DURATIONS[selected_weapon]
	muzzle_smoke_timer = 0.28
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
					shoot_spider(spider, bullet.color, bullet.position)
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


func notify_bug_outcome(killed: bool) -> void:
	if killed:
		bug_wave_killed += 1
	else:
		bug_wave_escaped += 1


func shoot_spider(spider: Area2D, impact_color: Color = Color("9ee7ff"), impact_position: Vector2 = Vector2.INF) -> void:
	if game_over:
		return
	var kill_value := int(spider.get("score_value"))
	score += kill_value
	weapon_parts += 2 if kill_value > 10 else 1
	spiders_shot += 1
	var spark_at: Vector2 = spider.position if impact_position == Vector2.INF else impact_position
	hit_sparks.append({
		"position": spark_at,
		"life": 0.26,
		"max_life": 0.26,
		"color": impact_color,
		"seed": random_source.randf() * TAU
	})
	if spiders_shot % 5 == 0:
		score += 25
		_show_kill_phrase()
	update_ui()
	if has_node("SquelchSound"):
		$SquelchSound.play()
	spider.hit()


func update_ui() -> void:
	var shown_wave := maxi(wave_number, 1)
	score_label.text = "SCORE %05d  W%02d" % [score, shown_wave]
	lives_label.text = "HOUSE  %02d / %02d" % [house_health, HOUSE_HEALTH]
	lives_label.add_theme_color_override("font_color", Color("ff5d65") if house_health <= 3 else Color("f4e6c9"))
	if reload_timer > 0.0:
		ammo_label.text = "RELOADING  %0.1fs" % reload_timer
	else:
		ammo_label.text = "%s  %d / %d" % [WEAPON_NAMES[selected_weapon], ammo, _weapon_capacity(selected_weapon)]
		ammo_label.add_theme_color_override("font_color", Color("ff696d") if ammo <= 2 else Color("ffc95c"))
	if nest_bonus_level > 0:
		parts_label.text = "PARTS  %02d   NEST x%d" % [weapon_parts, nest_bonus_level]
	else:
		parts_label.text = "PARTS  %02d" % weapon_parts
	_update_weapon_controls()
	_update_wave_banner()


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
		upgrade_button.text = "MAX UPGRADE" if nest_bonus_level == 0 else "MAX  ·  NEST x%d" % nest_bonus_level
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "UPGRADE %s · %d PARTS\n%s" % [WEAPON_NAMES[selected_weapon], cost, _upgrade_effect(selected_weapon)]
		upgrade_button.disabled = game_over or weapon_parts < cost


func _upgrade_effect(index: int) -> String:
	if index == 2:
		return "+2 PELLETS · +1 SHELL"
	if index == 1:
		return "+4 ROUNDS · FASTER"
	return "+2 ROUNDS · FASTER"


func _weapon_capacity(index: int) -> int:
	var level := weapon_levels[index]
	if index == 0:
		return WEAPON_CAPACITIES[index] + level * 2
	if index == 1:
		return WEAPON_CAPACITIES[index] + level * 4
	return WEAPON_CAPACITIES[index] + level


func _weapon_interval(index: int) -> float:
	return WEAPON_INTERVALS[index] * pow(0.92, weapon_levels[index]) * pow(0.9, nest_bonus_level)


func _weapon_reload_duration(index: int) -> float:
	return WEAPON_RELOADS[index] * pow(0.9, weapon_levels[index])


func _show_kill_phrase() -> void:
	_show_notice("%s   +25" % KILL_PHRASES[phrase_index % KILL_PHRASES.size()])
	phrase_index += 1


func _show_notice(message: String, duration: float = 2.1, color: Color = Color("ffc95c")) -> void:
	phrase_label.text = message
	phrase_timer = duration
	phrase_label.visible = true
	phrase_label.modulate.a = 1.0
	phrase_label.scale = Vector2(0.75, 0.75)
	phrase_label.add_theme_color_override("font_color", color)


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


func _gun_direction() -> Vector2:
	var direction := (gun_aim_position - GUN_ORIGIN).normalized()
	if direction.y > -0.08:
		direction = Vector2(direction.x, -0.35).normalized()
	return direction


func trigger_jump_scare() -> void:
	if game_over:
		return
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
	music_player.stream_paused = true
	if lady_scream != null and lady_scream.stream is AudioStreamWAV and (lady_scream.stream as AudioStreamWAV).data.size() > 0:
		lady_scream.play()
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


func _advance_waves(delta: float) -> void:
	if wave_break_timer > 0.0:
		wave_break_timer = maxf(wave_break_timer - delta, 0.0)
		if wave_break_timer == 0.0:
			_begin_wave(wave_number + 1)
	elif wave_remaining_to_spawn > 0:
		spawn_timer += delta
		var interval := _current_spawn_interval()
		if spawn_timer >= interval:
			spawn_timer -= interval
			spawn_spider()
			wave_remaining_to_spawn -= 1
	elif _living_spider_count() == 0:
		_finish_wave()


func _begin_wave(number: int) -> void:
	wave_number = number
	bug_wave_active = number % BUG_WAVE_EVERY == 0
	bug_wave_spawned = 0
	bug_wave_killed = 0
	bug_wave_escaped = 0
	wave_remaining_to_spawn = _wave_count(number)
	spawn_timer = 0.0
	if bug_wave_active:
		_show_notice("WAVE %d  ·  BUG-SPIDER SWARM" % number, 2.4, Color("d6ff4a"))
	else:
		_show_notice("WAVE %d  ·  %s" % [number, MAP_TITLES[map_index]], 1.8, _map_accent(map_index))
	update_ui()


func _finish_wave() -> void:
	var was_bug := bug_wave_active
	var spawned := bug_wave_spawned
	var escaped := bug_wave_escaped
	bug_wave_active = false
	var next_map := _map_index_for_wave(wave_number + 1)
	var changing_map := next_map != map_index
	wave_break_timer = 2.2 if was_bug or changing_map else 1.7
	if was_bug:
		if spawned > 0 and escaped == 0:
			_grant_bug_wave_upgrade()
		else:
			_show_notice("NO UPGRADE  ·  SWARM BROKE IN", 2.2, Color("ff5d65"))
	if changing_map:
		map_index = next_map
		map_flash = 0.72
		if not was_bug:
			_show_notice("ENTERING %s" % MAP_TITLES[map_index], 2.2, _map_accent(map_index))
	elif not was_bug:
		_show_notice("WAVE %d CLEAR" % wave_number, 1.6, Color("f4e6c9"))
	update_ui()


func _grant_bug_wave_upgrade() -> void:
	var index := selected_weapon
	if weapon_levels[index] >= WEAPON_MAX_LEVEL:
		for i in WEAPON_NAMES.size():
			if weapon_levels[i] < WEAPON_MAX_LEVEL:
				index = i
				break
	score += 150
	if weapon_levels[index] < WEAPON_MAX_LEVEL:
		weapon_levels[index] += 1
		weapon_reload_timers[index] = 0.0
		weapon_ammo[index] = _weapon_capacity(index)
		if index == selected_weapon:
			reload_timer = 0.0
			ammo = weapon_ammo[index]
			fire_timer = 0.0
		praised_weapon = index
		praised_timer = 2.6
		reward_flash = 0.55
		_show_notice("UPGRADED %s LV %d" % [WEAPON_NAMES[index], weapon_levels[index]], 2.4, Color("ffc95c"))
	else:
		nest_bonus_level += 1
		praised_weapon = selected_weapon
		praised_timer = 2.6
		reward_flash = 0.55
		_show_notice("NEST TOXIN  ·  FASTER FIRE", 2.4, Color("d6ff4a"))
	update_ui()


func _wave_count(number: int) -> int:
	if number % BUG_WAVE_EVERY == 0:
		return mini(12 + (number / BUG_WAVE_EVERY - 1) * 4, 28)
	return mini(6 + number * 2, 24)


func _current_spawn_interval() -> float:
	if bug_wave_active:
		return maxf(0.16, 0.30 - float(wave_number) * 0.008)
	return maxf(0.46, 1.2 - float(wave_number) * 0.05)


func _spawn_x() -> float:
	if bug_wave_active:
		var slot := bug_wave_spawned % 6
		return clampf(96.0 + float(slot) * 176.0 + random_source.randf_range(-42.0, 42.0), 36.0, VIEW_SIZE.x - 36.0)
	match map_index:
		1:
			if random_source.randf() < 0.5:
				return random_source.randf_range(48.0, 300.0)
			return random_source.randf_range(VIEW_SIZE.x - 300.0, VIEW_SIZE.x - 48.0)
		2:
			if random_source.randf() < 0.45:
				return random_source.randf_range(150.0, 420.0)
			return random_source.randf_range(430.0, 820.0)
		3:
			return random_source.randf_range(190.0, VIEW_SIZE.x - 190.0)
		_:
			return random_source.randf_range(48.0, VIEW_SIZE.x - 48.0)


func _map_index_for_wave(number: int) -> int:
	var index := 0
	for i in MAP_WAVE_MILESTONES.size():
		if number >= int(MAP_WAVE_MILESTONES[i]):
			index = i
	return index


func _map_accent(index: int) -> Color:
	return MAP_ACCENTS[clampi(index, 0, MAP_ACCENTS.size() - 1)]


func _living_spider_count() -> int:
	var count := 0
	for child in get_children():
		if child is Area2D and child.has_method("hit") and not child.is_queued_for_deletion():
			count += 1
	return count


func _update_wave_banner() -> void:
	var banner := get_node_or_null("CanvasLayer/Instructions") as Label
	if banner == null:
		return
	if bug_wave_active:
		var left := _living_spider_count() + wave_remaining_to_spawn
		if bug_wave_escaped > 0:
			banner.text = "BUG-SPIDER SWARM  ·  %d LEFT  ·  THE FLOOR WAS BREACHED" % left
			banner.add_theme_color_override("font_color", Color("ff5d65"))
		else:
			banner.text = "BUG-SPIDER SWARM  ·  %d LEFT  ·  NONE CAN REACH THE FLOOR" % left
			banner.add_theme_color_override("font_color", Color("d6ff4a"))
	else:
		banner.text = "%s   ·   HOLD FIRE  •  1-3 GUN  •  R RELOAD  •  U UPGRADE" % MAP_TITLES[map_index]
		banner.add_theme_color_override("font_color", Color(0.82, 0.72, 0.75))


func _update_gun_motion(delta: float) -> void:
	var follow := 1.0 - exp(-8.5 * delta)
	gun_aim_position = gun_aim_position.lerp(aim_position, follow)
	var direction := _gun_direction()
	var side := Vector2(-direction.y, direction.x)
	var error := aim_position - gun_aim_position
	var target_sway := clampf(error.dot(side) * 0.05, -18.0, 18.0)
	sway_offset = lerpf(sway_offset, target_sway, follow)
	var duration := maxf(WEAPON_RECOIL_DURATIONS[selected_weapon], 0.05)
	var snap := 0.2 / duration
	var stiffness := 210.0 * snap
	var damping := 8.5 + snap * 3.0
	recoil_velocity += (-stiffness * recoil_offset - damping * recoil_velocity) * delta
	recoil_offset += recoil_velocity * delta
	recoil_offset = clampf(recoil_offset, -10.0, 72.0)


func _update_praise(delta: float) -> void:
	if praised_timer > 0.0:
		praised_timer = maxf(praised_timer - delta, 0.0)
		var pulse := 0.55 + 0.45 * sin(praised_timer * 26.0)
		for i in weapon_buttons.size():
			if i == praised_weapon:
				weapon_buttons[i].modulate = Color(1.0, 0.78 + pulse * 0.22, 0.28 + pulse * 0.35)
			else:
				weapon_buttons[i].modulate = Color.WHITE
	elif praised_weapon != -1:
		for button in weapon_buttons:
			button.modulate = Color.WHITE
		praised_weapon = -1


func _setup_combat_fx() -> void:
	combat_fx = Node2D.new()
	combat_fx.name = "CombatFX"
	combat_fx.z_index = 20
	combat_fx.set_script(COMBAT_FX_SCRIPT)
	combat_fx.set("host", self)
	add_child(combat_fx)


func _setup_lady_scream() -> void:
	if has_node("ScreamSound"):
		$ScreamSound.volume_db = -14.0
	lady_scream = AudioStreamPlayer.new()
	lady_scream.name = "LadyScream"
	lady_scream.volume_db = 2.5
	lady_scream.stream = _load_wav_stream("res://assets/audio/lady_scream.wav")
	add_child(lady_scream)


func _load_wav_stream(path: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Lady scream missing at %s" % path)
		return stream
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		push_error("Lady scream wav is too small")
		return stream
	var offset := 12
	var channels := 1
	var rate := 44100
	var bits := 16
	var pcm := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		var body := offset + 8
		if chunk_id == "fmt " and body + 16 <= bytes.size():
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif chunk_id == "data":
			pcm = bytes.slice(body, mini(body + chunk_size, bytes.size()))
			break
		if chunk_size <= 0:
			break
		offset = body + chunk_size + (chunk_size & 1)
	stream.data = pcm
	stream.mix_rate = rate
	stream.stereo = channels >= 2
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	return stream


func _draw() -> void:
	draw_texture_rect(ROOM_BACKGROUND, Rect2(Vector2.ZERO, VIEW_SIZE), false)
	_draw_map_theme()
	_draw_bullets_on(self)
	_draw_shell_casings_on(self)
	_draw_gun_body(self)


func draw_world_fx(canvas: CanvasItem) -> void:
	_draw_bullet_heads_on(canvas)
	_draw_hit_sparks_on(canvas)
	_draw_muzzle_on(canvas)
	_draw_crosshair_on(canvas)
	if breach_flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 0.04, 0.06, breach_flash * 0.55))
	if map_flash > 0.0:
		var wash := _map_accent(map_index)
		wash.a = map_flash * 0.4
		canvas.draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), wash)
	if reward_flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(1.0, 0.84, 0.35, reward_flash * 0.28))


func _draw_map_theme() -> void:
	match map_index:
		1:
			_draw_cellar()
		2:
			_draw_nursery()
		3:
			_draw_nest()
		_:
			_draw_attic()


func _draw_attic() -> void:
	_draw_vignette(Color(0.08, 0.0, 0.02, 0.38), 64.0)
	_draw_floor_line(Color(1.0, 0.32, 0.38, 0.75))


func _draw_cellar() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.0, 0.07, 0.05, 0.58))
	for pipe_x in [110.0, 230.0, 910.0, 1036.0]:
		draw_rect(Rect2(pipe_x, 0, 26, 530), Color(0.05, 0.1, 0.09, 0.78))
		draw_line(Vector2(pipe_x + 7, 0), Vector2(pipe_x + 7, 530), Color(0.35, 0.85, 0.55, 0.35), 3.0)
		var drop_y := fmod(elapsed_time * (48.0 + pipe_x * 0.04) + pipe_x, 300.0)
		draw_line(Vector2(pipe_x + 18, 80), Vector2(pipe_x + 18, 80.0 + drop_y), Color(0.5, 1.0, 0.7, 0.28), 2.0)
		draw_circle(Vector2(pipe_x + 18, 80.0 + drop_y), 3.2, Color(0.65, 1.0, 0.75, 0.5))
	draw_rect(Rect2(0, 390, VIEW_SIZE.x, 160), Color(0.02, 0.12, 0.07, 0.28))
	_draw_vignette(Color(0.0, 0.04, 0.02, 0.7), 90.0)
	_draw_floor_line(Color(0.4, 1.0, 0.62, 0.85))


func _draw_nursery() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.22, 0.02, 0.08, 0.42))
	for stripe in range(16):
		var x := float(stripe) * 74.0
		draw_rect(Rect2(x, 0, 18, FLOOR_Y), Color(0.55, 0.12, 0.24, 0.16))
	draw_rect(Rect2(148, 348, 270, 176), Color(0.1, 0.02, 0.05, 0.62))
	draw_line(Vector2(148, 330), Vector2(148, 530), Color(0.45, 0.2, 0.28), 7.0)
	draw_line(Vector2(418, 330), Vector2(418, 530), Color(0.45, 0.2, 0.28), 7.0)
	draw_line(Vector2(148, 392), Vector2(418, 392), Color(0.62, 0.32, 0.42), 4.0)
	for rail in range(5):
		var rail_y := 408.0 + float(rail) * 20.0
		draw_line(Vector2(160, rail_y), Vector2(406, rail_y), Color(0.75, 0.4, 0.52, 0.55), 2.0)
	var anchor := Vector2(690, 28)
	var swing := sin(elapsed_time * 1.35) * 36.0
	draw_line(anchor, anchor + Vector2(swing, 110), Color(1.0, 0.75, 0.86, 0.85), 2.0)
	for bob in range(3):
		var drop := Vector2(swing * (0.35 + float(bob) * 0.28), 118.0 + float(bob) * 34.0)
		draw_circle(anchor + drop, 9.0, Color(1.0, 0.5, 0.68, 0.9))
	_draw_vignette(Color(0.16, 0.0, 0.05, 0.5), 72.0)
	_draw_floor_line(Color(1.0, 0.48, 0.66, 0.8))


func _draw_nest() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.12, 0.0, 0.02, 0.64))
	var center := Vector2(VIEW_SIZE.x * 0.5, 168.0 + sin(elapsed_time * 0.65) * 16.0)
	var anchors: Array[Vector2] = [
		Vector2(0, 0), Vector2(VIEW_SIZE.x, 0), Vector2(180, 0), Vector2(VIEW_SIZE.x - 180, 0),
		Vector2(0, 220), Vector2(VIEW_SIZE.x, 220)
	]
	for anchor_point in anchors:
		draw_line(anchor_point, center, Color(0.9, 0.86, 0.96, 0.28), 1.4)
	for ring in [64.0, 120.0, 190.0, 270.0]:
		draw_arc(center, ring, 0.0, TAU, 36, Color(0.86, 0.8, 0.95, 0.16), 1.2)
	for i in range(11):
		var y := float(i) * 50.0
		draw_line(Vector2(0, y), Vector2(150, y + 26), Color(0.92, 0.88, 1.0, 0.42), 2.0)
		draw_line(Vector2(VIEW_SIZE.x, y), Vector2(VIEW_SIZE.x - 150, y + 26), Color(0.92, 0.88, 1.0, 0.42), 2.0)
	var sacs: Array[Vector2] = [Vector2(230, 78), Vector2(430, 52), Vector2(640, 86), Vector2(860, 48), Vector2(1020, 74)]
	for sac_index in sacs.size():
		var sac: Vector2 = sacs[sac_index]
		var pulse := 1.0 + sin(elapsed_time * 2.1 + float(sac_index)) * 0.06
		draw_line(Vector2(sac.x, 0), sac, Color(0.8, 0.75, 0.88, 0.55), 1.2)
		draw_circle(sac, 16.0 * pulse, Color(0.38, 0.02, 0.08, 0.92))
		draw_circle(sac + Vector2(-4, -4), 5.5, Color(0.75, 0.16, 0.28, 0.85))
	_draw_vignette(Color(0.08, 0.0, 0.02, 0.72), 100.0)
	_draw_floor_line(Color(0.72, 0.28, 1.0, 0.85))


func _draw_vignette(color: Color, thickness: float) -> void:
	draw_rect(Rect2(0, 0, VIEW_SIZE.x, thickness), color)
	draw_rect(Rect2(0, VIEW_SIZE.y - thickness, VIEW_SIZE.x, thickness), color)
	draw_rect(Rect2(0, 0, thickness, VIEW_SIZE.y), color)
	draw_rect(Rect2(VIEW_SIZE.x - thickness, 0, thickness, VIEW_SIZE.y), color)


func _draw_floor_line(color: Color) -> void:
	var glow := color
	glow.a *= 0.22
	draw_rect(Rect2(0, FLOOR_Y - 16, VIEW_SIZE.x, 32), glow)
	draw_line(Vector2(0, FLOOR_Y), Vector2(VIEW_SIZE.x, FLOOR_Y), color, 3.0)


func _draw_bullets_on(canvas: CanvasItem) -> void:
	for bullet in bullets:
		var position: Vector2 = bullet.position
		var velocity: Vector2 = bullet.velocity
		var speed := maxf(velocity.length(), 1.0)
		var direction := velocity / speed
		var color: Color = bullet.color
		var trail: float = bullet.trail
		var girth: float = bullet.girth
		var trail_len := clampf(speed * 0.021, 16.0, 48.0) * trail
		canvas.draw_line(position - direction * trail_len, position, Color(color.r, color.g, color.b, 0.2), 11.0 * girth, false)
		canvas.draw_line(position - direction * trail_len * 0.75, position, Color(color.r, color.g, color.b, 0.78), 3.5 * girth, true)
		canvas.draw_line(position - direction * trail_len * 0.36, position + direction * 2.0, Color(1, 1, 1, 0.9), 1.6 * girth, true)
		canvas.draw_circle(position, 7.5 * girth, Color(color.r, color.g, color.b, 0.2))


func _draw_bullet_heads_on(canvas: CanvasItem) -> void:
	for bullet in bullets:
		var position: Vector2 = bullet.position
		var color: Color = bullet.color
		var girth: float = bullet.girth
		canvas.draw_circle(position, 3.4 * girth, Color(color.r, color.g, color.b, 0.95))
		canvas.draw_circle(position, 1.7 * girth, Color(1.0, 0.98, 0.94, 1.0))


func _draw_hit_sparks_on(canvas: CanvasItem) -> void:
	for spark in hit_sparks:
		var max_life: float = spark.max_life
		var life: float = spark.life
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var position: Vector2 = spark.position
		var color: Color = spark.color
		var radius := (1.0 - alpha) * 34.0 + 8.0
		canvas.draw_circle(position, radius * 0.42, Color(1, 1, 1, alpha * 0.55))
		canvas.draw_arc(position, radius, 0.0, TAU, 18, Color(color.r, color.g, color.b, alpha * 0.9), 3.0, true)
		canvas.draw_arc(position, radius * 0.62, 0.0, TAU, 14, Color(1, 0.95, 0.8, alpha * 0.75), 1.6, true)
		var seed: float = spark.seed
		for i in range(6):
			var ray := Vector2.RIGHT.rotated(seed + TAU * float(i) / 6.0)
			canvas.draw_line(position + ray * 5.0, position + ray * (12.0 + (1.0 - alpha) * 24.0), Color(color.r, color.g, color.b, alpha), 2.0, true)


func _draw_shell_casings_on(canvas: CanvasItem) -> void:
	for casing in shell_casings:
		var position: Vector2 = casing.position
		var casing_rotation: float = casing.rotation
		var half_width: float = casing.half_width
		var half_length: float = casing.half_length
		var shape := PackedVector2Array([
			position + Vector2(-half_width, -half_length).rotated(casing_rotation),
			position + Vector2(half_width, -half_length).rotated(casing_rotation),
			position + Vector2(half_width, half_length).rotated(casing_rotation),
			position + Vector2(-half_width, half_length).rotated(casing_rotation)
		])
		canvas.draw_colored_polygon(shape, casing.color)


func _gun_pose() -> Dictionary:
	var direction := _gun_direction()
	var side := Vector2(-direction.y, direction.x)
	var gun_height: float = [214.0, 200.0, 232.0][selected_weapon]
	var gun_width := gun_height * 1024.0 / 1536.0
	var reload_duration := _weapon_reload_duration(selected_weapon)
	var reload_progress := 1.0 - reload_timer / reload_duration if reload_timer > 0.0 else 0.0
	var reload_motion := sin(clampf(reload_progress, 0.0, 1.0) * PI)
	var reload_drops := [12.0, 7.0, 24.0]
	var reload_turns := [0.2, 0.06, 0.48]
	var reload_drop: float = reload_drops[selected_weapon] * reload_motion
	var reload_turn: float = reload_turns[selected_weapon] * reload_motion
	var twist_ratio: float = WEAPON_RECOIL_TWISTS[selected_weapon] / WEAPON_RECOIL_STRENGTHS[selected_weapon]
	var breathe := sin(elapsed_time * 2.35) * 3.2
	var idle_roll := sin(elapsed_time * 1.55) * 0.018
	var base := GUN_ORIGIN - direction * recoil_offset + side * sway_offset + Vector2(0.0, breathe + reload_drop)
	var spin := direction.angle() + PI * 0.5 + reload_turn + recoil_offset * twist_ratio + idle_roll
	var squeeze := clampf(recoil_offset / 80.0, 0.0, 0.14)
	var flash_boost := clampf(muzzle_flash_timer / WEAPON_FLASH_DURATIONS[selected_weapon], 0.0, 1.0)
	return {
		"direction": direction,
		"side": side,
		"base": base,
		"spin": spin,
		"squeeze": squeeze,
		"gun_width": gun_width,
		"gun_height": gun_height,
		"tip": base + direction * gun_height * 0.98,
		"modulate": Color(1, 1, 1).lerp(Color(1, 0.9, 0.64), flash_boost)
	}


func _draw_gun_body(canvas: CanvasItem) -> void:
	var pose := _gun_pose()
	var squeeze: float = pose.squeeze
	canvas.draw_set_transform(pose.base, pose.spin, Vector2(1.0 + squeeze, 1.0 - squeeze * 0.65))
	canvas.draw_texture_rect(GUN_ART[selected_weapon], Rect2(Vector2(-pose.gun_width * 0.5, -pose.gun_height), Vector2(pose.gun_width, pose.gun_height)), false, pose.modulate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_muzzle_on(canvas: CanvasItem) -> void:
	if muzzle_flash_timer <= 0.0 and muzzle_smoke_timer <= 0.0:
		return
	var pose := _gun_pose()
	var direction: Vector2 = pose.direction
	var tip: Vector2 = pose.tip
	if selected_weapon == 2:
		var side: Vector2 = pose.side
		_draw_muzzle_blast(canvas, tip + side * 6.0, direction, 2)
		_draw_muzzle_blast(canvas, tip - side * 6.0, direction, 2)
	else:
		_draw_muzzle_blast(canvas, tip, direction, selected_weapon)


func _draw_muzzle_blast(canvas: CanvasItem, tip: Vector2, direction: Vector2, weapon: int) -> void:
	var flash_amount := clampf(muzzle_flash_timer / WEAPON_FLASH_DURATIONS[weapon], 0.0, 1.0)
	var flash_scale: float = [0.9, 0.62, 1.35][weapon]
	var side := Vector2(-direction.y, direction.x)
	if flash_amount > 0.0:
		var cone_len := (20.0 + 16.0 * flash_amount) * flash_scale
		var cone_width := (6.0 + 7.0 * flash_amount) * flash_scale
		var far := tip + direction * cone_len
		canvas.draw_colored_polygon(PackedVector2Array([tip, far + side * cone_width, far - side * cone_width]), Color(1.0, 0.78, 0.32, 0.5 * flash_amount))
		canvas.draw_circle(tip, 6.5 * flash_scale * (0.45 + flash_amount), Color(1.0, 0.95, 0.78, 0.75 * flash_amount))
		var ray_count: int = [7, 5, 9][weapon]
		for ray in range(ray_count):
			var flash_direction := direction.rotated(TAU * float(ray) / float(ray_count) * 0.65 - 0.2)
			var start := tip + flash_direction * 2.0
			var finish := tip + direction * (8.0 * flash_scale) + flash_direction * (14.0 + float(ray % 3) * 5.0) * flash_scale
			canvas.draw_line(start, finish, Color(1.0, 0.84, 0.45, flash_amount), 2.2 * flash_scale, true)
	var smoke := clampf(muzzle_smoke_timer / 0.28, 0.0, 1.0)
	if smoke > 0.0:
		var puff := tip + direction * (8.0 + (1.0 - smoke) * 28.0)
		canvas.draw_circle(puff, 4.0 + (1.0 - smoke) * 16.0 * flash_scale, Color(0.92, 0.86, 0.74, smoke * 0.16))


func _draw_crosshair_on(canvas: CanvasItem) -> void:
	if game_over:
		return
	canvas.draw_arc(aim_position, 12.0, 0.0, TAU, 24, Color("ff696d"), 2.0)
	canvas.draw_line(aim_position + Vector2(-18, 0), aim_position + Vector2(-6, 0), Color("ff696d"), 2.0)
	canvas.draw_line(aim_position + Vector2(6, 0), aim_position + Vector2(18, 0), Color("ff696d"), 2.0)
	canvas.draw_line(aim_position + Vector2(0, -18), aim_position + Vector2(0, -6), Color("ff696d"), 2.0)
	canvas.draw_line(aim_position + Vector2(0, 6), aim_position + Vector2(0, 18), Color("ff696d"), 2.0)
