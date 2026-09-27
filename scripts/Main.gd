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
const WEAPON_RECOIL_STRENGTHS := [23.0, 11.0, 43.0]
const WEAPON_RECOIL_TWISTS := [0.075, 0.035, 0.18]
const WEAPON_FLASH_DURATIONS := [0.050, 0.033, 0.067]
const WEAPON_RECOIL_OMEGA := [22.0, 30.0, 16.0]
const WEAPON_COST_BASE := 4
const WEAPON_MAX_LEVEL := 3
const MAP_TITLES := ["THE ATTIC", "THE CELLAR", "THE NURSERY", "THE NEST"]
const MAP_WAVE_MILESTONES := [1, 4, 8, 12]
const MAP_ACCENTS := [Color("f4e6c9"), Color("7dffb2"), Color("ff9ec4"), Color("e7a6ff")]
const BUG_WAVE_EVERY := 5
const BULLET_POOL_SIZE := 64
const AIM_FOLLOW_RATE := 24.0
const SWAY_FOLLOW_RATE := 8.0
const AIM_ASSIST_RADIUS := 76.0
const AIM_ASSIST_MAX_MOUSE := 0.20
const AIM_ASSIST_MAX_TOUCH := 0.30
const SHOTGUN_HALF_ANGLE := 0.072
const HITSTOP_NORMAL := 2
const HITSTOP_BUG := 1
const SAVE_PATH := "user://web_crawler.cfg"
const INTRO_SCARE_AT := 6.2
const TIP_SECONDS := 4.8

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
var wave_break_timer := 0.35
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
var punch_camera: Camera2D
var bullet_pool: Array[Dictionary] = []
var shot_latch := false
var hitstop_frames := 0
var world_frozen := false
var cam_kick := Vector2.ZERO
var cam_kick_vel := Vector2.ZERO
var aim_assist_strength := 0.0
var aim_assist_point := Vector2.ZERO
var using_touch := false
var shell_players: Array[AudioStreamPlayer] = []
var upgrade_sound: AudioStreamPlayer
var pending_shell := -1
var pending_shell_time := 0.0
var best_score := 0
var best_wave := 0
var daily_best := 0
var daily_stamp := ""
var loaded_best := 0
var best_announced := false
var intro_scare_done := false
var run_seed := 0
var saved_best_score := -1
var saved_best_wave := -1
var saved_daily_best := -1

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
	jump_scare_layer.visible = false
	phrase_label.visible = false
	restart_button.pressed.connect(_restart_game)
	music_player.finished.connect(_loop_music)
	music_player.play()
	for index in range(weapon_buttons.size()):
		weapon_buttons[index].pressed.connect(_select_weapon.bind(index))
	upgrade_button.pressed.connect(_upgrade_selected_weapon)
	gun_aim_position = aim_position
	_seed_daily_run()
	_boot_bullet_pool()
	_setup_punch_camera()
	_setup_combat_fx()
	_setup_lady_scream()
	_setup_layered_sfx()
	_load_progress()
	update_ui()
	_show_notice("THE ATTIC", 1.15, _map_accent(0))
	queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_shell_audio(delta)
	if game_over:
		return
	if not using_touch:
		_sync_pointer_aim()

	world_frozen = hitstop_frames > 0
	if world_frozen:
		hitstop_frames -= 1
	var sim := 0.0 if world_frozen else delta
	if sim > 0.0:
		elapsed_time += sim
		fire_timer -= sim
		muzzle_flash_timer = maxf(muzzle_flash_timer - sim, 0.0)
		muzzle_smoke_timer = maxf(muzzle_smoke_timer - sim, 0.0)
		phrase_timer = maxf(phrase_timer - sim, 0.0)
		breach_flash = maxf(breach_flash - sim, 0.0)
		map_flash = maxf(map_flash - sim * 1.15, 0.0)
		reward_flash = maxf(reward_flash - sim * 0.85, 0.0)
		_update_gun_motion(sim)
		_update_praise(sim)
		_update_casings(sim)
		_update_hit_sparks(sim)
		_update_presence(sim)
		if reload_timer > 0.0:
			reload_timer = maxf(reload_timer - sim, 0.0)
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
		_advance_waves(sim)
		if not shot_latch and (mouse_is_down or touch_is_down) and fire_timer <= 0.0:
			fire_bullet()
		elif fire_timer < 0.0:
			fire_timer = 0.0
		update_bullets(sim)
	shot_latch = false
	_update_wave_banner()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_touch = false
		aim_position = _screen_to_world(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		using_touch = false
		mouse_is_down = event.pressed
		aim_position = _screen_to_world(event.position)
		if event.pressed:
			fire_bullet()
	elif event is InputEventScreenTouch:
		using_touch = true
		touch_is_down = event.pressed
		aim_position = _screen_to_world(event.position)
		if event.pressed:
			fire_bullet()
	elif event is InputEventScreenDrag:
		using_touch = true
		aim_position = _screen_to_world(event.position)
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
				_show_notice("RUNNER  +25", 1.4, Color("7dffb2"))
	add_child(spider)


func fire_bullet() -> void:
	if game_over or reload_timer > 0.0 or world_frozen or shot_latch:
		return
	if ammo <= 0:
		_start_reload()
		return
	if fire_timer > 0.0:
		return
	shot_latch = true
	_refresh_aim_assist()
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
			trail = 0.85
			girth = 0.78
		2:
			pellet_count = 5 + weapon_levels[2] * 2
			bullet_speed = 820.0
			bullet_color = Color("ff9e58")
			trail = 0.48
			girth = 1.05
	var muzzle_distance := 14.0
	for pellet in range(pellet_count):
		var shot_direction := direction
		if selected_weapon == 2:
			var span := float(pellet_count - 1)
			var centered := (float(pellet) - span * 0.5) / maxf(span * 0.5, 1.0)
			var jitter := random_source.randf_range(-0.008, 0.008)
			shot_direction = direction.rotated(centered * SHOTGUN_HALF_ANGLE + jitter)
		var index := _acquire_bullet()
		var slot: Dictionary = bullet_pool[index]
		slot.active = true
		slot.position = GUN_ORIGIN + shot_direction * muzzle_distance
		slot.velocity = shot_direction * bullet_speed
		slot.life = 1.15
		slot.max_life = 1.15
		slot.color = bullet_color
		slot.trail = trail
		slot.girth = girth
		bullet_pool[index] = slot
	ammo -= 1
	weapon_ammo[selected_weapon] = ammo
	fire_timer += _weapon_interval(selected_weapon)
	if fire_timer < 0.0:
		fire_timer = 0.0
	var kick: float = WEAPON_RECOIL_STRENGTHS[selected_weapon]
	recoil_offset = minf(recoil_offset + kick * 0.38, 56.0)
	recoil_velocity += kick * 2.4
	sway_offset += random_source.randf_range(-1.0, 1.0) * kick * 0.04
	muzzle_flash_timer = WEAPON_FLASH_DURATIONS[selected_weapon]
	muzzle_smoke_timer = 0.14
	weapon_sounds[selected_weapon].play()
	pending_shell = selected_weapon
	pending_shell_time = [0.055, 0.040, 0.072][selected_weapon]
	if selected_weapon != 0:
		_add_shell_casing()
	update_ui()
	if ammo == 0:
		_start_reload()
	queue_redraw()


func update_bullets(delta: float) -> void:
	var spiders: Array[Area2D] = []
	for child in get_children():
		if child is Area2D and child.has_method("hit") and not child.is_queued_for_deletion():
			spiders.append(child)
	for index in bullet_pool.size():
		var bullet: Dictionary = bullet_pool[index]
		if not bool(bullet.active):
			continue
		var position: Vector2 = bullet.position + bullet.velocity * delta
		bullet.position = position
		bullet.life = float(bullet.life) - delta
		var bullet_hit := false
		for spider in spiders:
			if spider.is_queued_for_deletion():
				continue
			var hit_radius: float = spider.get_hit_radius() + 5.0 if spider.has_method("get_hit_radius") else 29.0
			if position.distance_to(spider.position) <= hit_radius:
				shoot_spider(spider, bullet.color, position)
				bullet_hit = true
				break
		if bullet_hit or float(bullet.life) <= 0.0 or position.y < -40.0 or position.x < -40.0 or position.x > VIEW_SIZE.x + 40.0:
			bullet.active = false
		bullet_pool[index] = bullet


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
	var bug_kill := bool(spider.get("is_bug"))
	hit_sparks.append({
		"position": spark_at,
		"life": 0.16,
		"max_life": 0.16,
		"color": impact_color,
		"seed": random_source.randf() * TAU
	})
	var hold := HITSTOP_BUG if bug_kill else HITSTOP_NORMAL
	world_frozen = true
	hitstop_frames = maxi(hitstop_frames, hold - 1)
	_punch_on_kill(spark_at, 3.2 if bug_kill else 6.5)
	if spiders_shot % 5 == 0:
		score += 25
		_show_kill_phrase()
	_consider_records()
	update_ui()
	if has_node("SquelchSound"):
		$SquelchSound.pitch_scale = random_source.randf_range(0.94, 1.08)
		$SquelchSound.play()
	spider.hit()


func update_ui() -> void:
	score_label.text = "SCORE %05d" % score
	var best_label := get_node_or_null("CanvasLayer/BestLabel") as Label
	if best_label != null:
		best_label.text = "BEST %05d    TODAY %05d" % [best_score, daily_best]
		best_label.add_theme_color_override("font_color", Color("ffc95c") if best_announced else Color("e7c98a"))
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
	praised_weapon = selected_weapon
	praised_timer = 1.8
	reward_flash = 0.45
	_show_notice("%s  LV %d" % [WEAPON_NAMES[selected_weapon], weapon_levels[selected_weapon]], 1.35, Color("ffc95c"))
	_play_upgrade()
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
	var point := aim_position
	if aim_assist_strength > 0.0:
		point = aim_position.lerp(aim_assist_point, aim_assist_strength)
	var direction := (point - GUN_ORIGIN).normalized()
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
	_clear_bullets()
	_consider_records()
	_persist_progress()
	jump_scare_layer.visible = true
	game_over_label.text = "SHE FOUND YOU"
	game_over_label.visible = true
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
		$ScreamSound.volume_db = -14.0
		$ScreamSound.pitch_scale = 1.0
		$ScreamSound.play()


func _reveal_game_over() -> void:
	var headline := "NEW BEST" if score > loaded_best and score > 0 else "THE HOUSE IS LOST"
	game_over_label.text = "%s\n%s\n%05d" % [headline, MAP_TITLES[map_index], score]
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
	if number == 1 and not bug_wave_active:
		_show_notice("THEY'RE DROPPING", 1.2, _map_accent(map_index))
	elif bug_wave_active:
		_show_notice("BUG SWARM", 1.5, Color("d6ff4a"))
	else:
		_show_notice("WAVE %d" % number, 1.15, _map_accent(map_index))
	_consider_records()
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
			_show_notice("SWARM BROKE IN", 1.6, Color("ff5d65"))
	if changing_map:
		map_index = next_map
		map_flash = 0.72
		if not was_bug:
			_show_notice(MAP_TITLES[map_index], 1.6, _map_accent(map_index))
	elif not was_bug:
		_show_notice("WAVE CLEAR", 1.2, Color("f4e6c9"))
	_consider_records()
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
		_show_notice("%s  LV %d" % [WEAPON_NAMES[index], weapon_levels[index]], 1.6, Color("ffc95c"))
		_play_upgrade()
	else:
		nest_bonus_level += 1
		praised_weapon = selected_weapon
		praised_timer = 2.6
		reward_flash = 0.55
		_show_notice("NEST TOXIN", 1.6, Color("d6ff4a"))
		_play_upgrade()
	_consider_records()
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
	if elapsed_time < TIP_SECONDS and wave_number <= 1 and not bug_wave_active:
		banner.text = "THE ATTIC    ·    KEEP THEM OFF THE FLOOR"
		banner.add_theme_color_override("font_color", Color("f4e6c9"))
		return
	if bug_wave_active:
		var left := _living_spider_count() + wave_remaining_to_spawn
		if bug_wave_escaped > 0:
			banner.text = "BUG SWARM    ·    BREACH"
			banner.add_theme_color_override("font_color", Color("ff5d65"))
		else:
			banner.text = "BUG SWARM    ·    %d LEFT" % left
			banner.add_theme_color_override("font_color", Color("d6ff4a"))
		return
	banner.text = "%s    ·    WAVE %02d" % [MAP_TITLES[map_index], maxi(wave_number, 1)]
	banner.add_theme_color_override("font_color", _map_accent(map_index))


func _update_gun_motion(delta: float) -> void:
	_refresh_aim_assist()
	var follow := 1.0 - exp(-AIM_FOLLOW_RATE * delta)
	var sway_follow := 1.0 - exp(-SWAY_FOLLOW_RATE * delta)
	var look_target := aim_position
	if aim_assist_strength > 0.0:
		look_target = aim_position.lerp(aim_assist_point, aim_assist_strength * 0.45)
	gun_aim_position = gun_aim_position.lerp(look_target, follow)
	var direction := _gun_direction()
	var side := Vector2(-direction.y, direction.x)
	var error := look_target - gun_aim_position
	var target_sway := clampf(error.dot(side) * 0.035, -14.0, 14.0)
	sway_offset = lerpf(sway_offset, target_sway, sway_follow)
	var omega: float = WEAPON_RECOIL_OMEGA[selected_weapon]
	var accel := (-2.0 * omega * recoil_velocity) - (omega * omega * recoil_offset)
	recoil_velocity += accel * delta
	recoil_offset += recoil_velocity * delta
	recoil_offset = clampf(recoil_offset, -3.0, 62.0)


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


func _seed_daily_run() -> void:
	var date := Time.get_date_dict_from_system()
	run_seed = int(date.year) * 10000 + int(date.month) * 100 + int(date.day)
	daily_stamp = "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]
	seed(run_seed)
	random_source.seed = run_seed


func _boot_bullet_pool() -> void:
	bullet_pool.clear()
	for _i in BULLET_POOL_SIZE:
		bullet_pool.append({
			"active": false,
			"position": Vector2.ZERO,
			"velocity": Vector2.ZERO,
			"life": 0.0,
			"max_life": 1.15,
			"color": Color("ffc95c"),
			"trail": 1.0,
			"girth": 1.0
		})


func _acquire_bullet() -> int:
	for index in bullet_pool.size():
		if not bool(bullet_pool[index].active):
			return index
	var oldest := 0
	var oldest_life := float(bullet_pool[0].life)
	for index in bullet_pool.size():
		var life := float(bullet_pool[index].life)
		if life < oldest_life:
			oldest = index
			oldest_life = life
	return oldest


func _clear_bullets() -> void:
	for index in bullet_pool.size():
		var bullet: Dictionary = bullet_pool[index]
		bullet.active = false
		bullet_pool[index] = bullet


func _active_bullet_count() -> int:
	var count := 0
	for bullet in bullet_pool:
		if bool(bullet.active):
			count += 1
	return count


func _setup_punch_camera() -> void:
	punch_camera = Camera2D.new()
	punch_camera.name = "PunchCamera"
	punch_camera.position = VIEW_SIZE * 0.5
	punch_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(punch_camera)
	punch_camera.make_current()


func _update_camera(delta: float) -> void:
	var omega := 36.0
	var accel := (-2.0 * omega * cam_kick_vel) - (omega * omega * cam_kick)
	cam_kick_vel += accel * delta
	cam_kick += cam_kick_vel * delta
	if cam_kick.length() < 0.04 and cam_kick_vel.length() < 0.4:
		cam_kick = Vector2.ZERO
		cam_kick_vel = Vector2.ZERO
	if punch_camera != null:
		punch_camera.position = VIEW_SIZE * 0.5
		punch_camera.offset = cam_kick


func _punch_on_kill(at: Vector2, magnitude: float) -> void:
	var dir := at - VIEW_SIZE * 0.5
	if dir.length() < 8.0:
		dir = Vector2(random_source.randf_range(-1.0, 1.0), -1.0)
	dir = dir.normalized()
	cam_kick = dir * magnitude
	cam_kick_vel = dir * magnitude * 16.0


func _screen_to_world(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


func _sync_pointer_aim() -> void:
	if get_viewport() == null:
		return
	aim_position = _screen_to_world(get_viewport().get_mouse_position())


func _refresh_aim_assist() -> void:
	aim_assist_strength = 0.0
	aim_assist_point = aim_position
	var best_dist := AIM_ASSIST_RADIUS
	var found := false
	var found_pos := Vector2.ZERO
	for child in get_children():
		if not (child is Area2D) or not child.has_method("hit") or child.is_queued_for_deletion():
			continue
		var pos: Vector2 = child.position
		if pos.y > FLOOR_Y - 8.0:
			continue
		var dist := aim_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			found_pos = pos
			found = true
	if not found:
		return
	var firing := mouse_is_down or touch_is_down
	if best_dist > 48.0 and not firing:
		return
	var max_pull := AIM_ASSIST_MAX_TOUCH if using_touch else AIM_ASSIST_MAX_MOUSE
	var closeness := 1.0 - best_dist / AIM_ASSIST_RADIUS
	aim_assist_strength = clampf(closeness * max_pull * (1.15 if firing else 0.65), 0.0, max_pull)
	aim_assist_point = found_pos


func _setup_layered_sfx() -> void:
	var paths := [
		"res://assets/audio/shell_revolver.wav",
		"res://assets/audio/shell_pistol.wav",
		"res://assets/audio/shell_shotgun.wav"
	]
	var volumes: Array[float] = [-14.0, -12.0, -8.0]
	for i in paths.size():
		var player := AudioStreamPlayer.new()
		player.name = "ShellSound%d" % i
		player.volume_db = volumes[i]
		player.stream = _load_wav_stream(paths[i])
		add_child(player)
		shell_players.append(player)
	upgrade_sound = AudioStreamPlayer.new()
	upgrade_sound.name = "UpgradeSound"
	upgrade_sound.volume_db = -5.0
	upgrade_sound.stream = _load_wav_stream("res://assets/audio/upgrade_chime.wav")
	add_child(upgrade_sound)


func _update_shell_audio(delta: float) -> void:
	if pending_shell < 0:
		return
	pending_shell_time -= delta
	if pending_shell_time > 0.0:
		return
	var index := pending_shell
	pending_shell = -1
	if index >= 0 and index < shell_players.size():
		var player := shell_players[index]
		if player.stream is AudioStreamWAV and (player.stream as AudioStreamWAV).data.size() > 0:
			player.play()


func _play_upgrade() -> void:
	if upgrade_sound != null and upgrade_sound.stream is AudioStreamWAV and (upgrade_sound.stream as AudioStreamWAV).data.size() > 0:
		upgrade_sound.play()


func _update_presence(_delta: float) -> void:
	if intro_scare_done or elapsed_time < INTRO_SCARE_AT:
		return
	intro_scare_done = true
	breach_flash = maxf(breach_flash, 0.5)
	_show_notice("SHE HEARD YOU", 1.35, Color("ff5d65"))
	if has_node("ScreamSound"):
		$ScreamSound.volume_db = -6.0
		$ScreamSound.pitch_scale = 0.92
		$ScreamSound.play()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_score = int(cfg.get_value("meta", "best_score", 0))
	best_wave = int(cfg.get_value("meta", "best_wave", 0))
	loaded_best = best_score
	saved_best_score = best_score
	saved_best_wave = best_wave
	var saved_day := str(cfg.get_value("meta", "daily_stamp", ""))
	if saved_day == daily_stamp:
		daily_best = int(cfg.get_value("meta", "daily_best", 0))
		saved_daily_best = daily_best


func _consider_records() -> void:
	if loaded_best > 0 and not best_announced and score > loaded_best:
		best_announced = true
		reward_flash = maxf(reward_flash, 0.35)
		_show_notice("NEW BEST", 1.25, Color("ffc95c"))
	if score > best_score:
		best_score = score
	if wave_number > best_wave:
		best_wave = wave_number
	if score > daily_best:
		daily_best = score
	_persist_progress()


func _persist_progress() -> void:
	if best_score == saved_best_score and best_wave == saved_best_wave and daily_best == saved_daily_best:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "best_score", best_score)
	cfg.set_value("meta", "best_wave", best_wave)
	cfg.set_value("meta", "daily_stamp", daily_stamp)
	cfg.set_value("meta", "daily_best", daily_best)
	cfg.set_value("meta", "seed", run_seed)
	cfg.save(SAVE_PATH)
	saved_best_score = best_score
	saved_best_wave = best_wave
	saved_daily_best = daily_best


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
		push_error("WAV missing at %s" % path)
		return stream
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		push_error("WAV too small at %s" % path)
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
	for bullet in bullet_pool:
		if not bool(bullet.active):
			continue
		var position: Vector2 = bullet.position
		var velocity: Vector2 = bullet.velocity
		var speed := maxf(velocity.length(), 1.0)
		var direction := velocity / speed
		var color: Color = bullet.color
		var trail: float = bullet.trail
		var girth: float = bullet.girth
		var fade := clampf(float(bullet.life) / maxf(float(bullet.max_life), 0.001), 0.0, 1.0)
		fade *= fade
		var trail_len := clampf(speed * 0.016, 12.0, 34.0) * trail
		canvas.draw_line(position - direction * trail_len, position, Color(color.r, color.g, color.b, 0.10 * fade), 5.0 * girth, false)
		canvas.draw_line(position - direction * trail_len * 0.72, position, Color(color.r, color.g, color.b, 0.5 * fade), 2.2 * girth, true)
		canvas.draw_line(position - direction * trail_len * 0.28, position + direction * 1.5, Color(1, 1, 1, 0.62 * fade), 1.1 * girth, true)


func _draw_bullet_heads_on(canvas: CanvasItem) -> void:
	for bullet in bullet_pool:
		if not bool(bullet.active):
			continue
		var position: Vector2 = bullet.position
		var color: Color = bullet.color
		var girth: float = bullet.girth
		var fade := clampf(float(bullet.life) / maxf(float(bullet.max_life), 0.001), 0.0, 1.0)
		canvas.draw_circle(position, 2.6 * girth, Color(color.r, color.g, color.b, 0.9 * fade))
		canvas.draw_circle(position, 1.25 * girth, Color(1.0, 0.98, 0.94, fade))


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
	var smoke := clampf(muzzle_smoke_timer / 0.14, 0.0, 1.0)
	if smoke > 0.0:
		var puff := tip + direction * (6.0 + (1.0 - smoke) * 16.0)
		canvas.draw_circle(puff, 3.0 + (1.0 - smoke) * 8.0 * flash_scale, Color(0.92, 0.86, 0.74, smoke * 0.08))


func _draw_crosshair_on(canvas: CanvasItem) -> void:
	if game_over:
		return
	var sticky := clampf(aim_assist_strength / AIM_ASSIST_MAX_MOUSE, 0.0, 1.0)
	var color := Color("ff696d").lerp(Color("7dffb2"), sticky)
	canvas.draw_arc(aim_position, 12.0, 0.0, TAU, 24, color, 2.0)
	canvas.draw_line(aim_position + Vector2(-18, 0), aim_position + Vector2(-6, 0), color, 2.0)
	canvas.draw_line(aim_position + Vector2(6, 0), aim_position + Vector2(18, 0), color, 2.0)
	canvas.draw_line(aim_position + Vector2(0, -18), aim_position + Vector2(0, -6), color, 2.0)
	canvas.draw_line(aim_position + Vector2(0, 6), aim_position + Vector2(0, 18), color, 2.0)
	if sticky > 0.35:
		canvas.draw_arc(aim_assist_point, 16.0, 0.0, TAU, 20, Color(0.49, 1.0, 0.7, 0.35 * sticky), 1.5)
