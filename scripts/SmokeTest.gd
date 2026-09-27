extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in 3:
		await process_frame
	if not _check(main.bullet_pool.size() == main.BULLET_POOL_SIZE, "bullet pool size"):
		return
	if not _check(main.lady_scream != null, "lady scream node"):
		return
	var scream: AudioStream = main.lady_scream.stream
	if not _check(scream is AudioStreamWAV and (scream as AudioStreamWAV).data.size() > 1000, "lady scream buffer"):
		return
	if not _check(main.MAP_TITLES.size() == 4, "four maps"):
		return
	if not _check(str(main.MAP_TITLES[0]) == "THE ATTIC" and str(main.MAP_TITLES[3]) == "THE NEST", "map names"):
		return
	if not _check(main._map_index_for_wave(1) == 0 and main._map_index_for_wave(4) == 1 and main._map_index_for_wave(8) == 2 and main._map_index_for_wave(12) == 3, "map milestones"):
		return
	if not _check(main.run_seed > 20200000, "daily seed"):
		return
	_clear_spiders(main)
	await process_frame
	if not _check_fire_rate(main):
		return
	if not _check_shotgun_cone(main):
		return
	if not _check_pool_cap(main):
		return
	if not _check_recoil(main):
		return
	if not _check_aim_assist(main):
		return
	if not _check_hitstop(main):
		return
	if not _check_bug_upgrade(main):
		return
	main.score = 4321
	main.wave_number = 3
	main._consider_records()
	if not _check(main.best_score >= 4321, "best score updated"):
		return
	if not _check(FileAccess.file_exists("user://web_crawler.cfg"), "save file written"):
		return
	main.trigger_jump_scare()
	if not _check(main.game_over, "lady scare sets game over"):
		return
	if not _check(str(main.game_over_label.text) == "SHE FOUND YOU", "clip banner"):
		return
	print("SMOKE OK pool=%d seed=%d best=%d" % [main.bullet_pool.size(), main.run_seed, main.best_score])
	quit(0)


func _check_fire_rate(main: Node) -> bool:
	main.selected_weapon = 1
	main.weapon_levels[1] = 0
	main.nest_bonus_level = 0
	main.ammo = 12
	main.reload_timer = 0.0
	main.fire_timer = 0.0
	main.shot_latch = false
	main.hitstop_frames = 0
	main.mouse_is_down = false
	var interval: float = main._weapon_interval(1)
	main.fire_bullet()
	if not _check(absf(main.fire_timer - interval) < 0.0001, "pistol interval set"):
		return false
	main.fire_timer = -0.01
	main.shot_latch = false
	main.fire_bullet()
	return _check(absf(main.fire_timer - (interval - 0.01)) < 0.0001, "pistol remainder kept")


func _check_shotgun_cone(main: Node) -> bool:
	_clear_spiders(main)
	main._clear_bullets()
	main.selected_weapon = 2
	main.weapon_levels[2] = 3
	main.ammo = 8
	main.reload_timer = 0.0
	main.fire_timer = 0.0
	main.shot_latch = false
	main.hitstop_frames = 0
	main.using_touch = true
	main.mouse_is_down = false
	main.touch_is_down = false
	main.aim_position = Vector2(576, 180)
	main.gun_aim_position = main.aim_position
	main.aim_assist_strength = 0.0
	main.fire_bullet()
	var base: Vector2 = (main.aim_position - main.GUN_ORIGIN).normalized()
	var seen := 0
	var worst := 0.0
	for bullet in main.bullet_pool:
		if not bool(bullet.active):
			continue
		seen += 1
		var velocity: Vector2 = bullet.velocity
		var ang := absf(base.angle_to(velocity.normalized()))
		worst = maxf(worst, ang)
	var limit: float = main.SHOTGUN_HALF_ANGLE + 0.012
	if not _check(seen == 5 + 3 * 2, "shotgun pellet count"):
		return false
	return _check(worst <= limit, "shotgun cone %.4f <= %.4f" % [worst, limit])


func _check_pool_cap(main: Node) -> bool:
	var pool_size: int = main.bullet_pool.size()
	main.selected_weapon = 2
	main.weapon_levels[2] = 3
	main.ammo = 40
	main.reload_timer = 0.0
	main.hitstop_frames = 0
	for _i in 15:
		main.shot_latch = false
		main.fire_timer = 0.0
		main.fire_bullet()
	return _check(main.bullet_pool.size() == pool_size and main._active_bullet_count() <= pool_size, "pool does not grow")


func _check_recoil(main: Node) -> bool:
	main.selected_weapon = 0
	main.recoil_offset = 0.0
	main.recoil_velocity = 0.0
	main.ammo = 6
	main.reload_timer = 0.0
	main.fire_timer = 0.0
	main.shot_latch = false
	main.hitstop_frames = 0
	main.fire_bullet()
	if not _check(main.recoil_offset > 4.0, "recoil kick"):
		return false
	var lowest: float = main.recoil_offset
	for _i in 120:
		main._update_gun_motion(1.0 / 60.0)
		lowest = minf(lowest, main.recoil_offset)
	if not _check(lowest > -2.5, "recoil does not bounce"):
		return false
	return _check(absf(main.recoil_offset) < 1.5, "recoil settles")


func _check_aim_assist(main: Node) -> bool:
	_clear_spiders(main)
	var spider := (load("res://scenes/Spider.tscn") as PackedScene).instantiate() as Area2D
	spider.position = Vector2(430, 210)
	main.add_child(spider)
	main.aim_position = Vector2(400, 200)
	main.using_touch = false
	main.mouse_is_down = true
	main._refresh_aim_assist()
	if not _check(main.aim_assist_strength > 0.0 and main.aim_assist_strength <= main.AIM_ASSIST_MAX_MOUSE, "assist strength bounded"):
		return false
	var shot: Vector2 = main.aim_position.lerp(main.aim_assist_point, main.aim_assist_strength)
	var cursor_gap: float = main.aim_position.distance_to(spider.position)
	if not _check(shot.distance_to(spider.position) < cursor_gap, "assist moves toward spider"):
		return false
	return _check(shot.distance_to(main.aim_position) < cursor_gap * 0.35, "assist stays partial")


func _check_hitstop(main: Node) -> bool:
	_clear_spiders(main)
	var spider := (load("res://scenes/Spider.tscn") as PackedScene).instantiate() as Area2D
	spider.position = Vector2(120, 160)
	main.add_child(spider)
	main.hitstop_frames = 0
	main.game_over = false
	main.shoot_spider(spider, Color.WHITE, spider.position)
	if not _check(main.world_frozen and main.hitstop_frames == 1, "normal hitstop is two frames"):
		return false
	if not _check(main.cam_kick.length() > 1.0, "camera punch"):
		return false
	var bug := (load("res://scenes/Spider.tscn") as PackedScene).instantiate() as Area2D
	bug.configure_bug_spider()
	bug.position = Vector2(200, 160)
	main.add_child(bug)
	main.hitstop_frames = 0
	main.world_frozen = false
	main.shoot_spider(bug, Color.WHITE, bug.position)
	return _check(main.world_frozen and main.hitstop_frames == 0, "bug hitstop is one frame")


func _check_bug_upgrade(main: Node) -> bool:
	main.game_over = false
	main.selected_weapon = 0
	var before: int = main.weapon_levels[0]
	main._grant_bug_wave_upgrade()
	return _check(main.weapon_levels[0] == before + 1, "bug wave still upgrades")


func _clear_spiders(main: Node) -> void:
	for child in main.get_children():
		if child is Area2D and child.has_method("hit"):
			child.queue_free()


func _check(cond: bool, msg: String) -> bool:
	if cond:
		return true
	_fail(msg)
	return false


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("SMOKE FAIL: %s" % msg)
	quit(1)
