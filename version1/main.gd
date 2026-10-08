@tool
extends Node3D

class SkillArcMeter extends Control:
	var phase := 0.0

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y - 7.0)
		var radius := minf(size.x * 0.43, size.y - 13.0)
		draw_arc(center, radius, PI, TAU, 48, Color("39454a"), 13.0, true)
		_draw_zone(center, radius, 0.0, 0.23, Color("c94b4b"))
		_draw_zone(center, radius, 0.23, 0.38, Color("e8be4c"))
		_draw_zone(center, radius, 0.38, 0.62, Color("48bd72"))
		_draw_zone(center, radius, 0.62, 0.77, Color("e8be4c"))
		_draw_zone(center, radius, 0.77, 1.0, Color("c94b4b"))
		var angle := PI + phase * PI
		var tip := center + Vector2(cos(angle), sin(angle)) * (radius - 6.0)
		draw_line(center, tip, Color.WHITE, 2.5, true)
		draw_circle(tip, 4.0, Color.WHITE)

	func _draw_zone(center: Vector2, radius: float, from_phase: float, to_phase: float, color: Color) -> void:
		draw_arc(center, radius, PI + from_phase * PI, PI + to_phase * PI, 20, color, 10.0, true)

class SkillCelebration extends Control:
	var active := false
	var elapsed := 0.0
	var burst_center := Vector2.ZERO

	func play() -> void:
		active = true
		elapsed = 0.0
		burst_center = Vector2(size.x - 110.0, 165.0)
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= 1.15:
			active = false
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var progress := clampf(elapsed / 1.15, 0.0, 1.0)
		var colors := [Color("ffdf62"), Color("ff6e86"), Color("6ee9bc"), Color("79caff"), Color("d99bff")]
		draw_arc(burst_center, 10.0 + progress * 68.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.35, 1.0 - progress), 4.0, true)
		for i in range(34):
			var angle := float(i) * 2.39996
			var distance := progress * (22.0 + float(i % 6) * 10.0)
			var fall := progress * (24.0 + float(i % 5) * 8.0)
			var point := burst_center + Vector2(cos(angle) * distance, sin(angle) * distance + fall)
			var color: Color = colors[i % colors.size()]
			color.a = 1.0 - progress
			draw_rect(Rect2(point, Vector2(7.0, 11.0)), color)
		var title_color := Color(1.0, 0.95, 0.58, 1.0 - progress)
		draw_string(ThemeDB.fallback_font, burst_center + Vector2(-64.0, 93.0), "PERFECT! 100 PTS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, title_color)

const W := 12
const H := 8
const COST := 60
const DEFAULT_CAMERA_SIZE := 12.0
const ATTACK_INTERVAL_MULTIPLIER := 2.0
const ROUTE := [Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4),Vector2i(4,5),Vector2i(5,5),Vector2i(6,5),Vector2i(7,5),Vector2i(8,5),Vector2i(8,4),Vector2i(8,3),Vector2i(8,2),Vector2i(9,2),Vector2i(10,2),Vector2i(11,2)]
const PADS := [Vector2i(1,4),Vector2i(2,6),Vector2i(3,3),Vector2i(5,2),Vector2i(6,6),Vector2i(7,3),Vector2i(9,4),Vector2i(10,6),Vector2i(10,0),Vector2i(2,0)]

var gold := 120
var lives := 10
var wave := 0
var selected_tower := "Ranger"
var selected_placed_cell := Vector2i(-1,-1)
var camera_focus := Vector3.ZERO
var camera_yaw := 0.0
var camera_pitch := 0.0
var camera_distance := 34.2
var camera_shake_timer := 0.0
var camera_shake_duration := 0.0
var camera_shake_strength := 0.0
var camera_shake_offset := Vector3.ZERO
var rotating_camera := false
var panning_camera := false
var skill_active := false
var skill_phase := 0.0
var skill_direction := 1.0
var running := false
var game_over := false
var spawn_left := 0
var spawn_clock := 0.0
var boss_spawn_pending := false
var boss_spawn_delay := 0.0
var enemies: Array[Dictionary] = []
var towers: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var route_set := {}
var tower_cells := {}
var terrain_material_cache := {}
var path_lengths: Array[float] = []
var total_path := 0.0
var camera: Camera3D
var world_root: Node3D
var gold_label: Label
var lives_label: Label
var wave_label: Label
var message_label: Label
var wave_button: Button
var tower_buttons := {}
var tower_action_panel: PanelContainer
var tower_info_label: Label
var range_preview: Node3D
var range_preview_disc: MeshInstance3D
var placement_ghost_nodes: Array[Node] = []
var placement_ghost_cell := Vector2i(-1, -1)
var upgrade_tower_button: Button
var remove_tower_button: Button
var skill_button: Button
var skill_popup: PanelContainer
var skill_meter: SkillArcMeter
var skill_result_label: Label
var skill_celebration: SkillCelebration
var boss_alert_panel: PanelContainer
var boss_alert_label: Label
var boss_alert_tween: Tween

@export_group("Custom tower models")
@export var ranger_tower_model: PackedScene
@export var cannon_tower_model: PackedScene
@export var frost_tower_model: PackedScene
@export var ankan_tower_model: PackedScene

@export_group("Custom enemy model")
@export var enemy_model: PackedScene
@export var miangboss_model: PackedScene

func _ready() -> void:
	for c in ROUTE:
		route_set[c] = true
	if _create_world_root():
		_build_world()
	else:
		camera = world_root.get_node_or_null("Camera3D") as Camera3D
	if Engine.is_editor_hint():
		return
	_build_ui()
	_update_hud()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if skill_active:
		_update_skill_meter(delta)
	_update_camera_shake(delta)
	if running and boss_spawn_pending:
		boss_spawn_delay -= delta
		if boss_spawn_delay <= 0.0:
			boss_spawn_pending = false
			_spawn_enemy(true)
	if running and spawn_left > 0:
		spawn_clock -= delta
		if spawn_clock <= 0.0:
			_spawn_enemy()
			spawn_left -= 1
			spawn_clock = 0.82
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		enemy.slow_timer = maxf(enemy.slow_timer - delta, 0.0)
		enemy.roar_speed_timer = maxf(enemy.get("roar_speed_timer", 0.0) - delta, 0.0)
		var roar_speed_multiplier := 1.8 if enemy.roar_speed_timer > 0.0 else 1.0
		enemy.progress += enemy.speed * (0.42 if enemy.slow_timer > 0.0 else 1.0) * roar_speed_multiplier * delta
		enemy.hit_flash = maxf(enemy.hit_flash - delta, 0.0)
		if enemy.hit_flash > 0.0:
			enemy.body.material_override.albedo_color = Color("fff1b8")
		elif enemy.slow_timer > 0.0:
			enemy.body.material_override.albedo_color = Color("83eaff")
		else:
			enemy.body.material_override.albedo_color = enemy.base_color
		var p := _point_at(enemy.progress)
		var base_height := 0.22 if enemy.get("is_boss", false) else 0.40
		var jump_height := 0.0
		if enemy.get("is_boss", false):
			enemy.roar_delay -= delta
			if enemy.roar_delay <= 0.0:
				_trigger_boss_roar(enemy)
			if enemy.roar_started:
				enemy.roar_elapsed += delta
				var jump_phase := clampf(enemy.roar_elapsed / 0.82, 0.0, 1.0)
				jump_height = sin(jump_phase * PI) * 0.9
				var speech_bubble: Variant = enemy.get("speech_bubble", null)
				if is_instance_valid(speech_bubble):
					var valid_speech_bubble := speech_bubble as Node3D
					valid_speech_bubble.look_at(camera.global_position, Vector3.UP)
				if is_instance_valid(enemy.visual):
					var roar_pulse := sin(clampf(enemy.roar_elapsed / 0.24, 0.0, 1.0) * PI)
					enemy.visual.scale = enemy.visual_base_scale * Vector3(1.0 + roar_pulse * 0.09, 1.0 + roar_pulse * 0.12, 1.0 + roar_pulse * 0.09)
					if enemy.roar_elapsed > 0.82:
						enemy.visual.scale = enemy.visual_base_scale
		enemy.node.position = Vector3(p.x, base_height + jump_height + sin(Time.get_ticks_msec() * 0.008 + enemy.progress) * 0.025, p.y)
		var hp_billboard: Variant = enemy.get("hp_bar", null)
		if is_instance_valid(hp_billboard):
			var valid_hp_billboard := hp_billboard as Node3D
			valid_hp_billboard.look_at(camera.global_position, Vector3.UP)
		var facing_point := _point_at(minf(enemy.progress + 0.12, total_path))
		var move_direction := facing_point - p
		if move_direction.length_squared() > 0.001:
			enemy.node.rotation.y = atan2(-move_direction.x, -move_direction.y)
		enemies[i] = enemy
		if enemy.progress >= total_path:
			enemy.node.queue_free()
			enemies.remove_at(i)
			lives -= 1
			_update_hud()
			if lives <= 0:
				game_over = true
				running = false
				message_label.text = "The gate has fallen. Restart the game to try again."
				wave_button.text = "Game Over"
	for tower in towers:
		tower.cooldown -= delta
		tower.arm_timer = maxf(tower.arm_timer - delta, 0.0)
		if tower.arm_pivot and is_instance_valid(tower.arm_pivot):
			var arm_phase := clampf(1.0 - tower.arm_timer / 0.44, 0.0, 1.0)
			tower.arm_pivot.rotation.y = -1.15 * sin(arm_phase * PI)
	if enemies.size() > 0:
		for tower in towers:
			var target_index := _find_target(tower)
			if target_index >= 0:
				var target_position: Vector3 = enemies[target_index].node.position
				if tower.aim_node and tower.kind == "Ankan":
					var facing := Vector2(target_position.x - tower.x, target_position.z - tower.z)
					tower.aim_node.rotation.y = atan2(facing.x, facing.y)
				elif tower.get("aim_node") and is_instance_valid(tower.aim_node):
					var target_direction := Vector2(target_position.x - tower.x, target_position.z - tower.z)
					var target_yaw := atan2(-target_direction.x, -target_direction.y)
					tower.aim_node.rotation.y = lerp_angle(tower.aim_node.rotation.y, target_yaw, minf(delta * 8.0, 1.0))
				if tower.cooldown <= 0.0:
					_fire(tower, target_index)
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		shot.life -= delta
		var electric_arc: Variant = shot.get("electric_arc", null)
		if is_instance_valid(electric_arc):
			(electric_arc as Node3D).rotation.z += delta * 14.0
		var finish: Vector3 = shot.finish
		if is_instance_valid(shot.target):
			finish = shot.target.position + Vector3.UP * shot.aim_height
		var progress: float = clampf(1.0 - shot.life / shot.duration, 0.0, 1.0)
		shot.node.position = shot.start.lerp(finish, progress) + Vector3.UP * sin(progress * PI) * 0.35
		if shot.node.position.distance_to(finish) > 0.01:
			shot.node.look_at(finish, Vector3.UP)
		if shot.life <= 0.0:
			if is_instance_valid(shot.target):
				_hit_enemy(shot.target, shot.tower_kind, shot.damage)
			shot.node.queue_free()
			shots.remove_at(i)
	if running and spawn_left == 0 and enemies.is_empty() and not boss_spawn_pending:
		running = false
		wave_button.disabled = false
		wave_button.text = "Start Wave"
		gold += 25
		_update_hud()
		message_label.text = "Wave cleared! +25 bonus coins. Build and prepare for the next wave."

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111419")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a7afc0")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_bloom = 0.10
	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.35
	env.ssao_power = 1.35
	env.ssao_detail = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color("34302f")
	env.fog_density = 0.005
	env.fog_sun_scatter = 0.18
	world.environment = env
	world_root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.shadow_enabled = true
	light.light_color = Color("ffd5aa")
	light.light_energy = 1.6
	light.shadow_blur = 0.8
	light.shadow_bias = 0.025
	light.shadow_normal_bias = 1.0
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = 42.0
	light.directional_shadow_blend_splits = true
	world_root.add_child(light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.0, 5.0, -1.0)
	fill_light.light_color = Color("9bb9e9")
	fill_light.light_energy = 0.28
	fill_light.omni_range = 14.0
	fill_light.shadow_enabled = false
	world_root.add_child(fill_light)
	_add_atmosphere_motes()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DEFAULT_CAMERA_SIZE
	world_root.add_child(camera)
	camera_yaw = atan2(15.0,18.0)
	camera_pitch = atan2(25.0,sqrt(15.0*15.0 + 18.0*18.0))
	_update_camera_transform()
	camera.current = true
	var ground := _box(Vector3(12.2, 0.65, 8.2), Color("292a2c"), Vector3(0,-0.15,0))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Thin strata bands make the board read as a finished floating island.
	_box(Vector3(12.24,0.08,8.24), Color("57443b"), Vector3(0,-0.43,0))
	_box(Vector3(12.28,0.06,8.28), Color("1c1d20"), Vector3(0,-0.49,0))
	for z in range(H):
		for x in range(W):
			var cell := Vector2i(x,z)
			var p := _cell_pos(cell)
			if route_set.has(cell):
				# Set the warm trail one tile-height below the meadow surface.
				var path_base := _box(Vector3(0.98,0.32,0.98), Color("38302d"), Vector3(p.x,0.0,p.y))
				path_base.set_meta("cell", cell)
				var path_edge := _box(Vector3(0.92,0.055,0.92), Color("51423b"), Vector3(p.x,0.185,p.y))
				path_edge.material_override = _terrain_material(Color("51423b"), 1)
				var path_top := _box(Vector3(0.78,0.008,0.78), Color("25282a"), Vector3(p.x,0.217,p.y))
				path_top.material_override = _terrain_material(Color("25282a"), 1)
			else:
				var color: Color
				if cell in PADS:
					color = Color("35302d")
				else:
					var colors := [Color("34383a"), Color("3b3b38"), Color("303538")]
					color = colors[(x * 7 + z * 3) % colors.size()]
				var tile := _box(Vector3(0.97,0.32,0.97), color.darkened(0.08), Vector3(p.x,0.31,p.y))
				tile.set_meta("cell", cell)
				# A slightly inset top plate creates a soft bevel highlight without changing tile placement.
				var tile_top := _box(Vector3(0.91,0.045,0.91), color, Vector3(p.x,0.4875,p.y))
				tile_top.material_override = _terrain_material(color, 2 if cell in PADS else 0)
			if cell in PADS:
				_box(Vector3(0.25,0.035,0.25), Color("d3ad6a"), Vector3(p.x,0.522,p.y), 6)
			elif not route_set.has(cell) and (x * 5 + z * 7) % 13 == 0:
				_add_meadow_rock(p, 0.55 + float((x + z) % 4) * 0.08)
			elif not route_set.has(cell) and (x * 3 + z * 5) % 17 == 0:
				_add_meadow_bush(p, 0.65 + float((x + z) % 3) * 0.1)
			elif not route_set.has(cell) and (x * 11 + z * 7) % 6 == 0:
				_add_grass_tuft(p, 0.72 + float((x + z) % 4) * 0.08)
	_add_lava_route()
	# Basalt spires frame the board without changing the tile layout.
	for data in [[0,0,0.85],[3,0,0.7],[6,0,0.8],[11,1,0.85],[0,6,0.8],[1,7,0.95],[6,7,0.8],[11,7,0.9],[9,0,0.75]]:
		_add_rock_outcrop(int(data[0]), int(data[1]), float(data[2]))
	for cell in [Vector2i(2,2), Vector2i(6,1), Vector2i(9,6), Vector2i(3,6), Vector2i(10,5)]:
		if not route_set.has(cell) and not (cell in PADS):
			_add_industrial_crate(cell)
	# Gate at the end of the route.
	var end := _cell_pos(Vector2i(11,2))
	_box(Vector3(0.15,0.9,0.15), Color("80513c"), Vector3(end.x+0.85,0.64,end.y-0.34))
	_box(Vector3(0.15,0.9,0.15), Color("80513c"), Vector3(end.x+0.85,0.64,end.y+0.34))
	_box(Vector3(0.18,0.16,0.86), Color("c9503c"), Vector3(end.x+0.85,1.10,end.y))
	_box(Vector3(0.12,0.22,0.12), Color("e9b86c"), Vector3(end.x+0.85,0.82,end.y-0.35), 6)
	_box(Vector3(0.12,0.22,0.12), Color("e9b86c"), Vector3(end.x+0.85,0.82,end.y+0.35), 6)
	for i in range(1, ROUTE.size()):
		var a := _cell_pos(ROUTE[i-1])
		var b := _cell_pos(ROUTE[i])
		var length := a.distance_to(b)
		path_lengths.append(length)
		total_path += length

func _add_lava_route() -> void:
	var lava_material := _glow_mat(Color("ff4b1d"), 2.4)
	var hot_core_material := _glow_mat(Color("ffc05a"), 3.2)
	for i in range(ROUTE.size() - 1):
		var start := _cell_pos(ROUTE[i])
		var finish := _cell_pos(ROUTE[i + 1])
		var delta := finish - start
		var segment_length := start.distance_to(finish) + 0.08
		var center := start.lerp(finish, 0.5)
		var channel := MeshInstance3D.new()
		var channel_mesh := BoxMesh.new()
		channel_mesh.size = Vector3(0.19, 0.024, segment_length)
		channel.mesh = channel_mesh
		channel.position = Vector3(center.x, 0.237, center.y)
		channel.rotation.y = atan2(delta.x, delta.y)
		channel.material_override = lava_material
		channel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(channel)
		var hot_core := MeshInstance3D.new()
		var core_mesh := BoxMesh.new()
		core_mesh.size = Vector3(0.055, 0.012, segment_length - 0.04)
		hot_core.mesh = core_mesh
		hot_core.position = Vector3(center.x, 0.255, center.y)
		hot_core.rotation.y = channel.rotation.y
		hot_core.material_override = hot_core_material
		hot_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(hot_core)
		if i % 4 == 1:
			var lava_light := OmniLight3D.new()
			lava_light.position = Vector3(center.x, 0.42, center.y)
			lava_light.light_color = Color("ff612f")
			lava_light.light_energy = 0.8
			lava_light.omni_range = 3.2
			lava_light.shadow_enabled = false
			world_root.add_child(lava_light)

func _add_rock_outcrop(x: int, z: int, scale: float) -> void:
	var pos := _cell_pos(Vector2i(x, z))
	var outcrop := Node3D.new()
	outcrop.position = Vector3(pos.x, 0.50, pos.y)
	outcrop.scale = Vector3.ONE * scale
	world_root.add_child(outcrop)
	var boulder := MeshInstance3D.new()
	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radius = 0.52
	boulder_mesh.height = 0.76
	boulder_mesh.radial_segments = 7
	boulder_mesh.rings = 5
	boulder.mesh = boulder_mesh
	boulder.position = Vector3(0.0, 0.30, 0.0)
	boulder.scale = Vector3(1.25, 0.92, 1.08)
	boulder.rotation = Vector3(0.12, float(x + z) * 0.4, -0.08)
	var basalt_material := _mat(Color("35383b"))
	basalt_material.roughness = 0.94
	boulder.material_override = basalt_material
	outcrop.add_child(boulder)
	for i in range(3):
		var spire := MeshInstance3D.new()
		var spire_mesh := CylinderMesh.new()
		spire_mesh.top_radius = 0.035 + float(i % 2) * 0.025
		spire_mesh.bottom_radius = 0.27 - float(i) * 0.035
		spire_mesh.height = 0.68 + float((i + x) % 3) * 0.16
		spire_mesh.radial_segments = 6
		spire.mesh = spire_mesh
		spire.position = Vector3((float(i) - 1.0) * 0.26, 0.37 + spire_mesh.height * 0.32, float(i % 2) * 0.14 - 0.06)
		spire.rotation.z = (float(i) - 1.0) * 0.12
		spire.material_override = _mat(Color("454546") if i % 2 == 0 else Color("2c3033"))
		outcrop.add_child(spire)
	var ore_crack := MeshInstance3D.new()
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(0.035, 0.24, 0.22)
	ore_crack.mesh = crack_mesh
	ore_crack.position = Vector3(0.32, 0.29, 0.06)
	ore_crack.rotation.z = -0.35
	ore_crack.material_override = _glow_mat(Color("df5528"), 1.2)
	ore_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outcrop.add_child(ore_crack)

func _add_industrial_crate(cell: Vector2i) -> void:
	var pos := _cell_pos(cell)
	var crate := Node3D.new()
	crate.position = Vector3(pos.x, 0.51, pos.y)
	crate.rotation.y = float((cell.x * 3 + cell.y) % 4) * PI * 0.25
	world_root.add_child(crate)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.58, 0.46, 0.52)
	body.mesh = body_mesh
	body.position.y = 0.23
	body.material_override = _mat(Color("363b40"))
	crate.add_child(body)
	for side in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(0.62, 0.055, 0.065)
		brace.mesh = brace_mesh
		brace.position = Vector3(0.0, 0.09 if side < 0.0 else 0.37, side * 0.21)
		brace.material_override = _mat(Color("697078"))
		crate.add_child(brace)
	var front_panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.28, 0.12, 0.018)
	front_panel.mesh = panel_mesh
	front_panel.position = Vector3(0.0, 0.25, -0.269)
	front_panel.material_override = _glow_mat(Color("ef6b37"), 0.75)
	crate.add_child(front_panel)
	for i in range(4):
		var bolt := MeshInstance3D.new()
		var bolt_mesh := SphereMesh.new()
		bolt_mesh.radius = 0.025
		bolt_mesh.height = 0.05
		bolt_mesh.radial_segments = 5
		bolt_mesh.rings = 3
		bolt.mesh = bolt_mesh
		bolt.position = Vector3(-0.24 + float(i % 2) * 0.48, 0.16 + float(i / 2) * 0.17, -0.282)
		bolt.material_override = _mat(Color("b0a18c"))
		crate.add_child(bolt)

func _create_world_root() -> bool:
	var previous := get_node_or_null("GeneratedWorld")
	if previous:
		world_root = previous as Node3D
		return false
	world_root = Node3D.new()
	world_root.name = "GeneratedWorld"
	add_child(world_root)
	return true

func _update_camera_transform() -> void:
	var horizontal := cos(camera_pitch) * camera_distance
	var view_focus := camera_focus + camera_shake_offset
	camera.position = view_focus + Vector3(sin(camera_yaw)*horizontal,sin(camera_pitch)*camera_distance,cos(camera_yaw)*horizontal)
	camera.look_at(view_focus, Vector3.UP)

func _update_camera_shake(delta: float) -> void:
	if camera_shake_timer <= 0.0 and camera_shake_offset == Vector3.ZERO:
		return
	if camera_shake_timer > 0.0:
		camera_shake_timer = maxf(camera_shake_timer - delta, 0.0)
		var fade := camera_shake_timer / maxf(camera_shake_duration, 0.001)
		var right := camera.global_basis.x
		var up := camera.global_basis.y
		camera_shake_offset = (right * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) * camera_shake_strength * fade
	else:
		camera_shake_offset = Vector3.ZERO
	_update_camera_transform()

func _trigger_boss_roar(enemy: Dictionary) -> void:
	enemy.roar_started = true
	enemy.roar_elapsed = 0.0
	enemy.roar_delay = 5.0
	enemy.roar_speed_timer = 1.0
	camera_shake_duration = 0.9
	camera_shake_timer = camera_shake_duration
	camera_shake_strength = 0.24
	enemy.speech_bubble = _show_boss_speech(enemy.node)
	message_label.text = "MiangBoss roars and jumps! The ground shakes beneath it!"

func _show_boss_speech(boss: Node3D) -> Node3D:
	var bubble := Node3D.new()
	bubble.name = "MiangBossSpeech"
	bubble.position = Vector3(0,1.38,-0.16)
	bubble.scale = Vector3.ONE * 0.08
	boss.add_child(bubble)
	var cloud_material := _mat(Color("fffaf0"))
	for puff in [[Vector3.ZERO,Vector3(1.55,0.78,0.34),0.30],[Vector3(-0.32,0.02,0),Vector3(0.78,0.86,0.34),0.22],[Vector3(0.30,0.08,0),Vector3(0.76,0.92,0.34),0.23],[Vector3(-0.12,0.17,0),Vector3(0.88,0.84,0.34),0.23]]:
		var cloud_part := MeshInstance3D.new()
		var cloud_mesh := SphereMesh.new()
		cloud_mesh.radius = float(puff[2])
		cloud_mesh.height = float(puff[2]) * 2.0
		cloud_mesh.radial_segments = 10
		cloud_mesh.rings = 6
		cloud_part.mesh = cloud_mesh
		cloud_part.position = puff[0]
		cloud_part.scale = puff[1]
		cloud_part.material_override = cloud_material
		cloud_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubble.add_child(cloud_part)
	var label := Label3D.new()
	label.text = "TUA PUI!"
	label.font_size = 32
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color("3b2931")
	label.outline_size = 5
	label.outline_modulate = Color("fffaf0")
	label.position = Vector3(0,0.02,-0.19)
	bubble.add_child(label)
	bubble.look_at(camera.global_position, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(bubble, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.25)
	tween.tween_property(bubble, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(bubble.queue_free)
	create_tween().tween_property(bubble, "position:y", 1.68, 1.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return bubble

func _reset_camera() -> void:
	camera_focus = Vector3.ZERO
	camera_yaw = atan2(15.0,18.0)
	camera_pitch = atan2(25.0,sqrt(15.0*15.0 + 18.0*18.0))
	camera.size = DEFAULT_CAMERA_SIZE
	camera_shake_timer = 0.0
	camera_shake_offset = Vector3.ZERO
	_update_camera_transform()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 18
	panel.offset_top = 14
	panel.offset_right = -18
	panel.offset_bottom = 66
	panel.add_theme_stylebox_override("panel", _style(Color(0.045,0.065,0.09,0.94), 14))
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var title := Label.new()
	title.text = "🌿  TOWERDEFENDME"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f2f4e9"))
	title.add_theme_color_override("font_shadow_color", Color(0.02,0.05,0.04,0.65))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	gold_label = Label.new()
	lives_label = Label.new()
	wave_label = Label.new()
	for item in [gold_label,lives_label,wave_label]:
		item.add_theme_font_size_override("font_size", 18)
		item.add_theme_color_override("font_color", Color("f4e8bb"))
		row.add_child(item)
	var picker_panel := PanelContainer.new()
	picker_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	picker_panel.offset_left = 20
	picker_panel.offset_right = -20
	picker_panel.offset_top = -116
	picker_panel.offset_bottom = -66
	picker_panel.add_theme_stylebox_override("panel", _style(Color(0.045,0.065,0.09,0.96), 12))
	layer.add_child(picker_panel)
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 12)
	picker_panel.add_child(picker)
	for option in ["Ranger", "Cannon", "Frost", "Ankan"]:
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(180, 42)
		button.toggle_mode = true
		button.button_pressed = option == selected_tower
		_polish_button(button, Color("4c87b9"))
		var button_contents := HBoxContainer.new()
		button_contents.add_theme_constant_override("separation", 7)
		button_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button_contents.offset_left = 8
		button_contents.offset_right = -8
		button.add_child(button_contents)
		var tower_icon := Label.new()
		tower_icon.text = _tower_icon(option)
		tower_icon.add_theme_font_size_override("font_size", 20)
		tower_icon.add_theme_color_override("font_color", Color("dff3c8"))
		tower_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_contents.add_child(tower_icon)
		var tower_name := Label.new()
		tower_name.text = option
		tower_name.add_theme_font_size_override("font_size", 15)
		tower_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tower_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_contents.add_child(tower_name)
		var price := Label.new()
		var tower_cost: int = _tower_config(option).cost
		price.text = "Free" if tower_cost == 0 else str(tower_cost)
		price.add_theme_font_size_override("font_size", 14)
		price.add_theme_color_override("font_color", Color("f4e8bb"))
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_contents.add_child(price)
		var coin_icon := Label.new()
		coin_icon.text = String.chr(0x25CF)
		coin_icon.add_theme_font_size_override("font_size", 12)
		coin_icon.add_theme_color_override("font_color", Color("f4c95d"))
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_contents.add_child(coin_icon)
		button.pressed.connect(_select_tower.bind(option))
		picker.add_child(button)
		tower_buttons[option] = button
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -60
	bottom.offset_bottom = -10
	bottom.add_theme_constant_override("separation", 20)
	layer.add_child(bottom)
	message_label = Label.new()
	message_label.text = "Choose a tower and click a pad. Right-drag rotates; wheel zooms; R resets."
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_size_override("font_size", 16)
	bottom.add_child(message_label)
	skill_button = Button.new()
	skill_button.text = "Skill Check"
	skill_button.custom_minimum_size = Vector2(130, 42)
	skill_button.focus_mode = Control.FOCUS_NONE
	_polish_button(skill_button, Color("ae8de0"))
	skill_button.pressed.connect(_start_skill_check)
	bottom.add_child(skill_button)
	wave_button = Button.new()
	wave_button.text = "Start Wave"
	wave_button.custom_minimum_size = Vector2(145, 42)
	_polish_button(wave_button, Color("e4bd68"))
	wave_button.pressed.connect(_start_wave)
	bottom.add_child(wave_button)
	tower_action_panel = PanelContainer.new()
	tower_action_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tower_action_panel.offset_left = -270
	tower_action_panel.offset_top = 82
	tower_action_panel.offset_right = -18
	tower_action_panel.offset_bottom = 230
	tower_action_panel.visible = false
	tower_action_panel.add_theme_stylebox_override("panel", _style(Color(0.045,0.065,0.09,0.98), 12))
	layer.add_child(tower_action_panel)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	tower_action_panel.add_child(actions)
	tower_info_label = Label.new()
	tower_info_label.add_theme_font_size_override("font_size", 15)
	actions.add_child(tower_info_label)
	upgrade_tower_button = Button.new()
	upgrade_tower_button.text = "Upgrade · 100 gold"
	_polish_button(upgrade_tower_button, Color("e4bd68"))
	upgrade_tower_button.pressed.connect(_upgrade_selected_tower)
	actions.add_child(upgrade_tower_button)
	remove_tower_button = Button.new()
	remove_tower_button.text = "Remove tower"
	_polish_button(remove_tower_button, Color("d1786d"))
	remove_tower_button.pressed.connect(_remove_selected_tower)
	actions.add_child(remove_tower_button)
	skill_popup = PanelContainer.new()
	skill_popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skill_popup.offset_left = -200
	skill_popup.offset_top = 88
	skill_popup.offset_right = -18
	skill_popup.offset_bottom = 246
	skill_popup.visible = false
	skill_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_popup.add_theme_stylebox_override("panel", _style(Color(0.035,0.05,0.075,0.98), 14))
	layer.add_child(skill_popup)
	var skill_content := VBoxContainer.new()
	skill_content.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_content.add_theme_constant_override("separation", 4)
	skill_popup.add_child(skill_content)
	var skill_title := Label.new()
	skill_title.text = "SKILL CHECK · SPACE"
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_title.add_theme_font_size_override("font_size", 13)
	skill_content.add_child(skill_title)
	skill_meter = SkillArcMeter.new()
	skill_meter.custom_minimum_size = Vector2(150, 82)
	skill_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_content.add_child(skill_meter)
	skill_result_label = Label.new()
	skill_result_label.text = ""
	skill_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_result_label.add_theme_font_size_override("font_size", 13)
	skill_content.add_child(skill_result_label)
	skill_celebration = SkillCelebration.new()
	skill_celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_celebration.set_process(false)
	layer.add_child(skill_celebration)
	boss_alert_panel = PanelContainer.new()
	boss_alert_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_alert_panel.offset_left = -170
	boss_alert_panel.offset_top = 74
	boss_alert_panel.offset_right = 170
	boss_alert_panel.offset_bottom = 118
	boss_alert_panel.visible = false
	var alert_style := _style(Color(0.23,0.07,0.07,0.96), 12)
	alert_style.border_color = Color("e0ad62")
	alert_style.set_border_width_all(2)
	boss_alert_panel.add_theme_stylebox_override("panel", alert_style)
	layer.add_child(boss_alert_panel)
	boss_alert_label = Label.new()
	boss_alert_label.text = "Boss appear!"
	boss_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert_label.add_theme_font_size_override("font_size", 19)
	boss_alert_label.add_theme_color_override("font_color", Color("ffe3a1"))
	boss_alert_panel.add_child(boss_alert_label)

func _show_boss_alert(text: String, hold_seconds: float = 0.45) -> void:
	if boss_alert_tween and boss_alert_tween.is_running():
		boss_alert_tween.kill()
	boss_alert_label.text = text
	boss_alert_panel.visible = true
	boss_alert_panel.modulate = Color.WHITE
	boss_alert_panel.scale = Vector2(0.82, 0.82)
	boss_alert_panel.pivot_offset = boss_alert_panel.size * 0.5
	boss_alert_tween = create_tween()
	boss_alert_tween.tween_property(boss_alert_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	boss_alert_tween.tween_interval(hold_seconds)
	boss_alert_tween.tween_property(boss_alert_panel, "modulate:a", 0.0, 0.30)
	boss_alert_tween.tween_callback(func():
		boss_alert_panel.visible = false
		boss_alert_panel.modulate = Color.WHITE
	)

func _start_skill_check() -> void:
	if skill_active:
		return
	if towers.is_empty():
		message_label.text = "Build a tower before starting the Skill Check."
		return
	skill_active = true
	skill_phase = 0.0
	skill_direction = 1.0
	skill_popup.visible = true
	skill_result_label.text = ""
	skill_button.disabled = true

func _update_skill_meter(delta: float) -> void:
	skill_phase += delta * 0.95 * skill_direction
	if skill_phase >= 1.0:
		skill_phase = 1.0
		skill_direction = -1.0
	elif skill_phase <= 0.0:
		skill_phase = 0.0
		skill_direction = 1.0
	skill_meter.phase = skill_phase
	skill_meter.queue_redraw()

func _resolve_skill_check() -> void:
	if not skill_active:
		return
	skill_active = false
	skill_popup.visible = false
	skill_button.disabled = false
	if skill_phase >= 0.38 and skill_phase <= 0.62:
		for i in range(towers.size()):
			var tower: Dictionary = towers[i]
			tower.empowered = true
			towers[i] = tower
		skill_result_label.text = "100 pts · Perfect!"
		message_label.text = "Perfect timing! Each tower's next shot is empowered once."
		skill_celebration.play()
	elif skill_phase >= 0.23 and skill_phase <= 0.77:
		skill_result_label.text = "50 pts · Close!"
		message_label.text = "Close timing! Try the Skill Check again for the green zone."
	else:
		skill_result_label.text = "0 pts · Miss!"
		message_label.text = "Missed the timing window. Try the Skill Check again."

func _select_tower(kind: String) -> void:
	selected_tower = kind
	selected_placed_cell = Vector2i(-1, -1)
	tower_action_panel.visible = false
	_clear_placement_ghost()
	if range_preview:
		range_preview.visible = false
	for option in tower_buttons:
		tower_buttons[option].button_pressed = option == kind
	var config: Dictionary = _tower_config(kind)
	var cost_text := "Free" if config.cost == 0 else "%d coins" % config.cost
	message_label.text = "%s selected - %s - Range %.1f tiles. Hover over a pad to preview. %s" % [kind, cost_text, config.range, config.description]

func _tower_icon(kind: String) -> String:
	match kind:
		"Ranger":
			return String.chr(0x27A4)
		"Cannon":
			return String.chr(0x25C9)
		"Frost":
			return String.chr(0x2744)
		"Ankan":
			return String.chr(0x2726)
	return String.chr(0x25C6)

func _ensure_range_preview() -> void:
	if range_preview:
		return
	range_preview = Node3D.new()
	range_preview.name = "TowerRangeCoverage"
	range_preview.visible = false
	range_preview_disc = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.012
	disc_mesh.radial_segments = 64
	range_preview_disc.mesh = disc_mesh
	var coverage_material := StandardMaterial3D.new()
	coverage_material.albedo_color = Color(0.37, 0.82, 0.94, 0.075)
	coverage_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	coverage_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coverage_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_preview_disc.material_override = coverage_material
	range_preview_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_preview.add_child(range_preview_disc)
	world_root.add_child(range_preview)

func _show_range_coverage(center: Vector2, attack_range: float) -> void:
	_ensure_range_preview()
	var disc_mesh := range_preview_disc.mesh as CylinderMesh
	disc_mesh.top_radius = attack_range
	disc_mesh.bottom_radius = attack_range
	range_preview.position = Vector3(center.x, 0.535, center.y)
	range_preview.visible = true

func _update_build_range_preview(screen_position: Vector2) -> void:
	if selected_placed_cell.x >= 0 or tower_action_panel.visible:
		_clear_placement_ghost()
		return
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.001:
		return
	var distance := (0.515 - origin.y) / direction.y
	if distance <= 0.0:
		_clear_placement_ghost()
		if range_preview:
			range_preview.visible = false
		return
	var hit := origin + direction * distance
	var cell := Vector2i(floori(hit.x + W * 0.5), floori(hit.z + H * 0.5))
	if not (cell in PADS) or tower_cells.has(cell):
		_clear_placement_ghost()
		if range_preview:
			range_preview.visible = false
		return
	var config: Dictionary = _tower_config(selected_tower)
	_show_placement_ghost(cell)
	_show_range_coverage(_cell_pos(cell), config.range)

func _show_placement_ghost(cell: Vector2i) -> void:
	if placement_ghost_cell == cell and not placement_ghost_nodes.is_empty():
		return
	_clear_placement_ghost()
	var visual_start := world_root.get_child_count()
	_build_tower_visual(_cell_pos(cell), selected_tower)
	for node in world_root.get_children().slice(visual_start):
		placement_ghost_nodes.append(node)
		_set_placement_ghost_appearance(node)
	placement_ghost_cell = cell

func _clear_placement_ghost() -> void:
	for node in placement_ghost_nodes:
		if is_instance_valid(node):
			node.queue_free()
	placement_ghost_nodes.clear()
	placement_ghost_cell = Vector2i(-1, -1)

func _set_placement_ghost_appearance(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source: Material = mesh_instance.get_active_material(surface)
				var ghost_material: StandardMaterial3D
				if source is StandardMaterial3D:
					ghost_material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					ghost_material = StandardMaterial3D.new()
					ghost_material.albedo_color = Color("a8d7ed")
				ghost_material.roughness = 0.55
				ghost_material.metallic = 0.22
				ghost_material.emission_enabled = true
				ghost_material.emission = Color("4b9abf")
				ghost_material.emission_energy_multiplier = 0.35
				ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_material.albedo_color.a = 0.5
				mesh_instance.set_surface_override_material(surface, ghost_material)
	for child in node.get_children():
		_set_placement_ghost_appearance(child)

func _tower_config(kind: String) -> Dictionary:
	match kind:
		"Cannon":
			return {"cost":110,"range":4.0,"rate":1.45,"description":"Slow shots splash nearby enemies."}
		"Frost":
			return {"cost":85,"range":3.1,"rate":0.95,"description":"Icy shots slow enemies for a short time."}
		"Ankan":
			return {"cost":0,"range":4.0,"rate":1.05,"description":"Purple bolts jump to nearby enemies."}
		_:
			return {"cost":60,"range":3.4,"rate":0.72,"description":"Fast shots hit one enemy."}

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.36, 0.56, 0.78, 0.30)
	box.set_border_width_all(1)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.03, 0.07, 0.06, 0.24)
	box.shadow_size = 7
	box.shadow_offset = Vector2(0, 3)
	return box

func _button_box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _polish_button(button: Button, accent: Color = Color("79b867")) -> void:
	button.add_theme_stylebox_override("normal", _button_box(Color("1c2926"), Color(0.66,0.78,0.60,0.28)))
	button.add_theme_stylebox_override("hover", _button_box(Color("30463a"), accent))
	button.add_theme_stylebox_override("pressed", _button_box(Color("466849"), accent.lightened(0.12)))
	button.add_theme_stylebox_override("disabled", _button_box(Color("202b27"), Color(0.45,0.52,0.44,0.16)))
	button.add_theme_stylebox_override("focus", _button_box(Color("273b32"), accent))
	button.add_theme_color_override("font_color", Color("f3f3e8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("a3aca2"))

func _box(size: Vector3, color: Color, pos: Vector3, sides: int = 4) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	if sides == 6:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 6
		var instance := MeshInstance3D.new()
		instance.mesh = cylinder
		instance.material_override = _mat(color)
		instance.position = pos
		world_root.add_child(instance)
		return instance
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	world_root.add_child(node)
	return node

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	m.metallic = 0.02
	return m

func _terrain_material(color: Color, surface_kind: int) -> ShaderMaterial:
	var cache_key := "%s:%d" % [color.to_html(false), surface_kind]
	if terrain_material_cache.has(cache_key):
		return terrain_material_cache[cache_key] as ShaderMaterial
	var terrain_shader := Shader.new()
	terrain_shader.code = """
	shader_type spatial;
	uniform vec4 base_color : source_color = vec4(0.3, 0.5, 0.25, 1.0);
	uniform int surface_kind = 0;
	float hash_value(vec2 p) {
		return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
	}
	float noise_value(vec2 p) {
		vec2 i = floor(p);
		vec2 f = fract(p);
		f = f * f * (3.0 - 2.0 * f);
		return mix(mix(hash_value(i), hash_value(i + vec2(1.0, 0.0)), f.x),
			mix(hash_value(i + vec2(0.0, 1.0)), hash_value(i + vec2(1.0, 1.0)), f.x), f.y);
	}
	void fragment() {
		vec2 p = UV * 6.0;
		float broad = noise_value(p * 0.23);
		float grain = noise_value(p * 1.8);
		float detail = noise_value(p * 3.5);
		vec3 color = base_color.rgb;
		if (surface_kind == 0) {
			float ash = noise_value(p * 0.48 + vec2(4.2, 1.7));
			color *= 0.76 + broad * 0.25 + grain * 0.12;
			color = mix(color, color * vec3(1.12, 0.91, 0.78), smoothstep(0.52, 0.82, ash) * 0.18);
			color += vec3(0.045, 0.027, 0.018) * smoothstep(0.78, 0.96, detail);
		} else if (surface_kind == 1) {
			float pebble = smoothstep(0.73, 0.92, detail);
			color *= 0.76 + broad * 0.20 + grain * 0.15;
			color = mix(color, color * vec3(0.68, 0.56, 0.43), pebble * 0.28);
		} else {
			float packed_soil = noise_value(p * 3.2);
			color *= 0.76 + broad * 0.20 + packed_soil * 0.12;
			color += vec3(0.035, 0.022, 0.012) * smoothstep(0.72, 0.96, detail);
		}
		ALBEDO = color;
		ROUGHNESS = surface_kind == 0 ? 0.88 : 0.94;
		SPECULAR = 0.18;
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = terrain_shader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("surface_kind", surface_kind)
	terrain_material_cache[cache_key] = material
	return material

func _add_atmosphere_motes() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "AmbientMotes"
	motes.position = Vector3(0.0, 1.1, 0.0)
	motes.amount = 18
	motes.lifetime = 7.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 7.2
	motes.direction = Vector3(0.0, 1.0, 0.0)
	motes.spread = 160.0
	motes.gravity = Vector3(0.0, 0.015, 0.0)
	motes.initial_velocity_min = 0.04
	motes.initial_velocity_max = 0.16
	motes.scale_amount_min = 0.45
	motes.scale_amount_max = 0.9
	motes.color = Color(0.82, 0.92, 0.61, 0.28)
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.035
	mote_mesh.height = 0.07
	mote_mesh.radial_segments = 5
	mote_mesh.rings = 3
	var mote_material := _glow_mat(Color(0.82, 0.92, 0.61, 0.28), 0.35)
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mesh.material = mote_material
	motes.mesh = mote_mesh
	motes.emitting = true
	world_root.add_child(motes)

func _improve_imported_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if not source:
					continue
				var pbr := source.duplicate() as StandardMaterial3D
				pbr.roughness = clampf(pbr.roughness, 0.42, 0.92)
				pbr.metallic = minf(pbr.metallic, 0.58)
				mesh_instance.set_surface_override_material(surface, pbr)
	for child in node.get_children():
		_improve_imported_materials(child)

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x - (W-1)*0.5, cell.y - (H-1)*0.5)

func _nearest_path_direction(pos: Vector2) -> Vector2:
	var nearest := _cell_pos(ROUTE[0])
	var nearest_distance := INF
	for cell in ROUTE:
		var path_pos := _cell_pos(cell)
		var distance := pos.distance_squared_to(path_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = path_pos
	return (nearest - pos).normalized()

func _add_tree(x: int, z: int, scale: float) -> void:
	var p := _cell_pos(Vector2i(x,z))
	var tree := Node3D.new()
	tree.position = Vector3(p.x,0.47,p.y)
	world_root.add_child(tree)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.12 * scale
	stem_mesh.bottom_radius = 0.18 * scale
	stem_mesh.height = 0.7 * scale
	stem_mesh.radial_segments = 5
	stem.mesh = stem_mesh
	stem.position.y = 0.34 * scale
	stem.material_override = _mat(Color("946348"))
	var branch := MeshInstance3D.new()
	var branch_mesh := CylinderMesh.new()
	branch_mesh.top_radius = 0.055 * scale
	branch_mesh.bottom_radius = 0.09 * scale
	branch_mesh.height = 0.48 * scale
	branch_mesh.radial_segments = 5
	branch.mesh = branch_mesh
	branch.position = Vector3(0.08 * scale, 0.76 * scale, 0.02 * scale)
	branch.rotation.z = -0.52
	branch.material_override = _mat(Color("80523d"))
	tree.add_child(branch)
	tree.add_child(stem)
	for offset in [Vector3(0,0.95,0),Vector3(0.24,1.28,0.05),Vector3(-0.26,1.12,-0.08),Vector3(0.02,1.48,0.02)]:
		var crown := MeshInstance3D.new()
		var ico := SphereMesh.new()
		ico.radius = (0.62 if offset.y < 1.0 else 0.4) * scale
		ico.height = ico.radius * 2.0
		ico.radial_segments = 7
		ico.rings = 4
		crown.mesh = ico
		crown.position = offset * scale
		var leaf_material := _mat([Color("286844"),Color("347b4b"),Color("24603e")][(x+z+3)%3])
		leaf_material.roughness = 0.9
		crown.material_override = leaf_material
		tree.add_child(crown)
	var low_crown := MeshInstance3D.new()
	var low_mesh := SphereMesh.new()
	low_mesh.radius = 0.42 * scale
	low_mesh.height = 0.72 * scale
	low_mesh.radial_segments = 8
	low_mesh.rings = 4
	low_crown.mesh = low_mesh
	low_crown.position = Vector3(-0.23,0.88,0.12) * scale
	low_crown.material_override = _mat(Color("348b57"))
	tree.add_child(low_crown)

func _add_meadow_rock(pos: Vector2, scale: float) -> void:
	var cluster := Node3D.new()
	cluster.position = Vector3(pos.x + 0.25, 0.50, pos.y + 0.23)
	world_root.add_child(cluster)
	for i in range(3):
		var stone := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.13 * scale
		mesh.height = 0.20 * scale
		mesh.radial_segments = 6
		mesh.rings = 4
		stone.mesh = mesh
		stone.scale = [Vector3(1.45,0.78,1.08),Vector3(0.92,0.68,0.86),Vector3(0.78,0.58,0.72)][i]
		stone.position = Vector3(float(i-1)*0.15*scale, 0.035*float(i%2), float(i%2)*0.10)
		stone.rotation = Vector3(0.18 * float(i), 0.62 * float(i), 0.12 * float(i-1))
		var stone_material := _mat([Color("686f60"),Color("8a806d"),Color("5a6656")][i])
		stone_material.roughness = 0.96
		stone.material_override = stone_material
		cluster.add_child(stone)
	var chip := MeshInstance3D.new()
	var chip_mesh := SphereMesh.new()
	chip_mesh.radius = 0.055 * scale
	chip_mesh.height = 0.08 * scale
	chip_mesh.radial_segments = 5
	chip_mesh.rings = 3
	chip.mesh = chip_mesh
	chip.position = Vector3(0.24 * scale, 0.015, -0.13 * scale)
	chip.material_override = _mat(Color("a29475"))
	cluster.add_child(chip)

func _add_meadow_bush(pos: Vector2, scale: float) -> void:
	var bush := Node3D.new()
	bush.position = Vector3(pos.x - 0.25, 0.52, pos.y + 0.24)
	world_root.add_child(bush)
	for i in range(3):
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.15 * scale
		leaf_mesh.height = 0.22 * scale
		leaf_mesh.radial_segments = 7
		leaf_mesh.rings = 4
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(float(i-1)*0.12, 0.05 + float(i%2)*0.04, float(i%2)*0.08)
		leaf.material_override = _mat([Color("66533d"),Color("766145"),Color("4c4939")][i])
		bush.add_child(leaf)
	var berry := MeshInstance3D.new()
	var berry_mesh := SphereMesh.new()
	berry_mesh.radius = 0.045 * scale
	berry_mesh.height = 0.07 * scale
	berry_mesh.radial_segments = 6
	berry_mesh.rings = 3
	berry.mesh = berry_mesh
	berry.position = Vector3(0.08, 0.17 * scale, -0.10)
	berry.material_override = _glow_mat(Color("e47135"), 0.38)
	bush.add_child(berry)

func _add_grass_tuft(pos: Vector2, scale: float) -> void:
	var tuft := Node3D.new()
	tuft.position = Vector3(pos.x + 0.22, 0.515, pos.y - 0.18)
	world_root.add_child(tuft)
	for i in range(4):
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.045 * scale, 0.24 * scale, 0.035 * scale)
		blade.mesh = blade_mesh
		blade.position = Vector3(float(i % 2) * 0.045 * scale, 0.11 * scale, float(i / 2) * 0.04 * scale)
		blade.rotation.z = (float(i) - 1.5) * 0.17
		blade.rotation.y = float(i) * 0.8
		blade.material_override = _mat([Color("514437"),Color("706044"),Color("9a7748")][i % 3])
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tuft.add_child(blade)

func _start_wave() -> void:
	if running or game_over:
		return
	wave += 1
	spawn_left = 5 + wave * 2
	boss_spawn_pending = wave == 1
	boss_spawn_delay = 2.0 if boss_spawn_pending else 0.0
	spawn_clock = 0.0
	running = true
	wave_button.text = "Wave in progress"
	wave_button.disabled = true
	message_label.text = "Wave %d: %d little troublemakers incoming!" % [wave, spawn_left]
	if boss_spawn_pending:
		message_label.text = "Boss appear! MiangBoss arrives in 2 seconds!"
		_show_boss_alert("Boss appear!")
	_update_hud()

func _spawn_enemy(is_boss: bool = false) -> void:
	var enemy := Node3D.new()
	var body: MeshInstance3D
	var base_color := Color("8b4264") if is_boss else Color("ed8944")
	var visual_scene := miangboss_model if is_boss else enemy_model
	var visual_node: Node3D
	var visual_base_scale := Vector3.ONE
	if visual_scene:
		visual_node = visual_scene.instantiate() as Node3D
		if visual_node:
			_improve_imported_materials(visual_node)
			if is_boss:
				# The imported boss model is Z-up; convert it to the game's Y-up world.
				visual_node.rotation.x = -PI / 2.0
				# The imported face points backward after the axis conversion.
				visual_node.rotation.y = PI
				visual_base_scale = Vector3.ONE * 0.75
				visual_node.scale = visual_base_scale
				body = _find_named_mesh(visual_node, "HoodieBody")
				if not body:
					body = _find_named_mesh(visual_node, "MiangBoss_Head")
			else:
				body = visual_node.get_node_or_null("Body") as MeshInstance3D
			if not body:
				body = _find_first_mesh(visual_node)
			enemy.add_child(visual_node)
	if not body:
		body = MeshInstance3D.new()
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.28
		body_mesh.height = 0.48
		body_mesh.radial_segments = 6
		body_mesh.rings = 3
		body.mesh = body_mesh
		body.scale = Vector3(1.15,0.82,1.0)
		body.material_override = _mat(base_color)
		enemy.add_child(body)
		if is_boss:
			body.scale = Vector3(1.6,2.4,1.5)
	else:
		var source_material := body.get_active_material(0) as StandardMaterial3D
		if source_material:
			body.material_override = source_material.duplicate()
			base_color = body.material_override.albedo_color
		else:
			body.material_override = _mat(base_color)
	add_child(enemy)
	var hp := 2 + int((wave-1)/2)
	var speed := 1.2 + wave * 0.07
	if is_boss:
		hp = 26 + wave * 4
		speed = 0.82 + wave * 0.025
	var enemy_data := {"node":enemy,"body":body,"base_color":base_color,"progress":0.0,"hp":hp,"max_hp":hp,"speed":speed,"hit_flash":0.0,"slow_timer":0.0,"is_boss":is_boss}
	var visual_top := _get_visual_top_in_local_space(enemy, visual_node) if visual_node else 0.0
	var hp_bar_data := _create_enemy_hp_bar(enemy, is_boss, visual_top)
	enemy_data.hp_bar = hp_bar_data.root
	enemy_data.hp_fill = hp_bar_data.fill
	enemy_data.hp_fill_material = hp_bar_data.material
	enemy_data.hp_bar_width = hp_bar_data.width
	enemy_data.hp_bar_tween = null
	if is_boss:
		enemy_data.roar_delay = 4.0
		enemy_data.roar_started = false
		enemy_data.roar_elapsed = 0.0
		enemy_data.roar_speed_timer = 0.0
		enemy_data.visual = visual_node
		enemy_data.visual_base_scale = visual_base_scale
	enemies.append(enemy_data)
	if is_boss:
		message_label.text = "MiangBoss has entered the path!"
		_show_boss_alert("MIANGBOSS ENTERS!")

func _find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var nested := _find_first_mesh(child)
		if nested:
			return nested
	return null

func _find_named_mesh(node: Node, name_fragment: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name).contains(name_fragment):
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_named_mesh(child, name_fragment)
		if found:
			return found
	return null

func _get_visual_top_in_local_space(root: Node3D, current: Node) -> float:
	var highest := 0.0
	if current is MeshInstance3D:
		var mesh_instance := current as MeshInstance3D
		if mesh_instance.mesh:
			var bounds := mesh_instance.get_aabb()
			var to_root := root.global_transform.affine_inverse() * mesh_instance.global_transform
			for x in [bounds.position.x, bounds.position.x + bounds.size.x]:
				for y in [bounds.position.y, bounds.position.y + bounds.size.y]:
					for z in [bounds.position.z, bounds.position.z + bounds.size.z]:
						highest = maxf(highest, (to_root * Vector3(x, y, z)).y)
	for child in current.get_children():
		highest = maxf(highest, _get_visual_top_in_local_space(root, child))
	return highest

func _create_enemy_hp_bar(enemy: Node3D, is_boss: bool, visual_top: float = 0.0) -> Dictionary:
	var bar_width := 1.08 if is_boss else 0.56
	var bar_root := Node3D.new()
	bar_root.name = "EnemyHealthBar"
	bar_root.position.y = maxf(visual_top + 0.32, 2.08) if is_boss else 0.46
	enemy.add_child(bar_root)
	if is_boss:
		var boss_frame := MeshInstance3D.new()
		var boss_frame_mesh := BoxMesh.new()
		boss_frame_mesh.size = Vector3(bar_width + 0.08,0.12,0.045)
		boss_frame.mesh = boss_frame_mesh
		boss_frame.material_override = _mat(Color("b58a4e"))
		boss_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar_root.add_child(boss_frame)
	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(bar_width,0.08,0.04)
	background.mesh = background_mesh
	background.material_override = _mat(Color("3a2027"))
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_root.add_child(background)
	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	var fill_width := bar_width - (0.08 if is_boss else 0.045)
	fill_mesh.size = Vector3(fill_width,0.052,0.025)
	fill.mesh = fill_mesh
	fill.position.z = -0.035
	var fill_material := _glow_mat(Color("e44956"), 0.18)
	fill.material_override = fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_root.add_child(fill)
	return {"root":bar_root,"fill":fill,"material":fill_material,"width":fill_width}

func _animate_enemy_hp_bar(enemy: Dictionary) -> void:
	var fill: MeshInstance3D = enemy.hp_fill
	if not is_instance_valid(fill):
		return
	var previous_tween: Tween = enemy.hp_bar_tween
	if previous_tween and previous_tween.is_running():
		previous_tween.kill()
	var ratio := clampf(float(enemy.hp) / float(enemy.max_hp), 0.0, 1.0)
	var target_width: float = enemy.hp_bar_width
	fill.scale.y = 1.75
	_flash_hp_fill(enemy.hp_fill_material)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fill, "scale:x", maxf(ratio, 0.01), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fill, "position:x", -target_width * (1.0 - ratio) * 0.5, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fill, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy.hp_fill_material, "albedo_color", Color("e44956"), 0.28)
	enemy.hp_bar_tween = tween

func _flash_hp_fill(material: StandardMaterial3D) -> void:
	material.albedo_color = Color("fff0bf")

func _remove_named_nodes(node: Node, target_name: String) -> void:
	for child in node.get_children():
		if child.name == target_name:
			child.free()
		else:
			_remove_named_nodes(child, target_name)

func _point_at(distance: float) -> Vector2:
	var d := distance
	for i in range(path_lengths.size()):
		var length := path_lengths[i]
		if d <= length:
			var a := _cell_pos(ROUTE[i])
			var b := _cell_pos(ROUTE[i+1])
			return a.lerp(b,d/length)
		d -= length
	return _cell_pos(ROUTE[-1])

func _find_target(tower: Dictionary) -> int:
	var best := -1
	var farthest := -1.0
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var p := _point_at(e.progress)
		if Vector2(tower.x,tower.z).distance_to(p) < tower.range and e.progress > farthest:
			best = i
			farthest = e.progress
	return best

func _fire(tower: Dictionary, index: int) -> void:
	if index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var kind: String = tower.kind
	var empowered: bool = tower.get("empowered", false)
	var core_color := Color("713b91")
	var trail_color := Color("54266f")
	var tail_color := Color("35154c")
	var core_radius := 0.1
	match kind:
		"Cannon":
			core_color = Color("ffab45")
			trail_color = Color("f06d34")
			tail_color = Color("b83c2f")
			core_radius = 0.16
		"Frost":
			core_color = Color("a8f7ff")
			trail_color = Color("54d9ef")
			tail_color = Color("3687d8")
			core_radius = 0.12
		"Ankan":
			core_color = Color("bd78ff")
			trail_color = Color("7838c7")
			tail_color = Color("472078")
			core_radius = 0.13
	var start := Vector3(tower.x,1.72,tower.z)
	var finish: Vector3 = enemy.node.position
	var aim_height := 0.0
	if enemy.get("is_boss", false):
		aim_height = 0.95
		finish += Vector3.UP * aim_height
	var bullet := Node3D.new()
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = core_radius
	core_mesh.height = core_radius * 2.0
	core_mesh.radial_segments = 24
	core_mesh.rings = 14
	core.mesh = core_mesh
	core.scale = Vector3(1.0,0.8,1.4)
	core.material_override = _glow_mat(core_color, 1.8)
	bullet.add_child(core)
	for detail in [[0.13,core_radius*0.75,trail_color],[0.24,core_radius*0.5,tail_color]]:
		var trail := MeshInstance3D.new()
		var trail_mesh := SphereMesh.new()
		trail_mesh.radius = float(detail[1])
		trail_mesh.height = float(detail[1]) * 2.0
		trail_mesh.radial_segments = 12
		trail_mesh.rings = 8
		trail.mesh = trail_mesh
		trail.position.z = float(detail[0])
		trail.material_override = _glow_mat(detail[2], 1.6)
		bullet.add_child(trail)
	var streak := MeshInstance3D.new()
	var streak_mesh := CapsuleMesh.new()
	streak_mesh.radius = core_radius * 0.19
	streak_mesh.height = core_radius * 7.5
	streak_mesh.radial_segments = 16
	streak_mesh.rings = 8
	streak.mesh = streak_mesh
	streak.rotation.x = PI * 0.5
	streak.position.z = core_radius * 3.6
	var streak_material := _glow_mat(trail_color, 1.1)
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color.a = 0.28
	streak.material_override = streak_material
	bullet.add_child(streak)
	var projectile_trail := _make_projectile_trail(kind, trail_color)
	bullet.add_child(projectile_trail)
	var electric_arc: Node3D
	if kind == "Ankan":
		electric_arc = _add_bolt_electricity(bullet, core_radius)
	if empowered:
		bullet.scale = Vector3.ONE * 5.0
	bullet.position = start
	if start.distance_to(finish) > 0.01:
		bullet.look_at(finish, Vector3.UP)
	add_child(bullet)
	_spawn_muzzle_flash(start, core_color)
	_animate_tower_fire(tower, kind)
	var damage_multiplier := 5 if empowered else 1
	shots.append({"node":bullet,"target":enemy.node,"tower_kind":kind,"damage":tower.damage * damage_multiplier,"start":start,"finish":finish,"aim_height":aim_height,"duration":0.28,"life":0.28,"electric_arc":electric_arc})
	if empowered:
		tower.empowered = false
	tower.cooldown = tower.rate * ATTACK_INTERVAL_MULTIPLIER
	if kind == "Ankan":
		tower.arm_timer = 0.44

func _make_projectile_trail(kind: String, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 7 if kind == "Cannon" else 5
	particles.lifetime = 0.24 if kind == "Cannon" else 0.18
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.035
	particles.direction = Vector3(0.0, 0.0, 1.0)
	particles.spread = 26.0
	particles.gravity = Vector3(0.0, 0.25, 0.0) if kind == "Cannon" else Vector3.ZERO
	particles.initial_velocity_min = 0.10
	particles.initial_velocity_max = 0.38
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.8
	particles.color = Color(0.20, 0.18, 0.17, 0.42) if kind == "Cannon" else Color(color.r, color.g, color.b, 0.72)
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.035 if kind == "Cannon" else 0.025
	particle_mesh.height = particle_mesh.radius * 2.0
	particle_mesh.radial_segments = 9
	particle_mesh.rings = 6
	var particle_material := _glow_mat(particles.color, 0.65 if kind == "Cannon" else 1.25)
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mesh.material = particle_material
	particles.mesh = particle_mesh
	particles.emitting = true
	return particles

func _add_bolt_electricity(parent: Node3D, radius: float) -> Node3D:
	var arc_root := Node3D.new()
	arc_root.name = "BoltElectricity"
	var arc_mesh := ImmediateMesh.new()
	var arc_material := _glow_mat(Color("d9a0ff"), 3.0)
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES, arc_material)
	for strand in range(3):
		var previous := Vector3(0.0, 0.0, 0.0)
		for step in range(1, 6):
			var phase := float(step) / 5.0
			var angle := float(strand) * TAU / 3.0 + float(step) * 1.72
			var point := Vector3(cos(angle) * radius * 1.45, sin(angle) * radius * 1.45, -phase * radius * 4.8)
			arc_mesh.surface_add_vertex(previous)
			arc_mesh.surface_add_vertex(point)
			previous = point
		arc_mesh.surface_add_vertex(previous)
		arc_mesh.surface_add_vertex(Vector3(0.0, 0.0, -radius * 4.8))
	arc_mesh.surface_end()
	var arc_instance := MeshInstance3D.new()
	arc_instance.mesh = arc_mesh
	arc_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc_root.add_child(arc_instance)
	parent.add_child(arc_root)
	return arc_root

func _spawn_muzzle_flash(position: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.11
	flash_mesh.height = 0.22
	flash_mesh.radial_segments = 14
	flash_mesh.rings = 10
	flash.mesh = flash_mesh
	flash.position = position
	flash.scale = Vector3(0.35, 0.55, 0.35)
	var flash_material := _glow_mat(color.lightened(0.25), 2.4)
	flash.material_override = flash_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(1.5, 1.8, 1.5), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.12)
	tween.chain().tween_callback(flash.queue_free)

func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := _mat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _spawn_impact_vfx(position: Vector3, kind: String) -> void:
	var color := Color("f7d27b")
	match kind:
		"Cannon":
			color = Color("ff9b56")
		"Frost":
			color = Color("8deaff")
		"Ankan":
			color = Color("bd78ff")
	var burst := Node3D.new()
	burst.position = position + Vector3(0,0.12,0)
	world_root.add_child(burst)
	burst.add_child(_make_impact_particles(color.lightened(0.24), 10, 2.8))
	if kind == "Frost":
		for i in range(5):
			var angle := TAU * float(i) / 5.0
			var shard := MeshInstance3D.new()
			var shard_mesh := CylinderMesh.new()
			shard_mesh.top_radius = 0.008
			shard_mesh.bottom_radius = 0.035
			shard_mesh.height = 0.20
			shard_mesh.radial_segments = 8
			shard.mesh = shard_mesh
			shard.position = Vector3(cos(angle) * 0.14, 0.08, sin(angle) * 0.14)
			shard.rotation.z = -0.24
			shard.material_override = _glow_mat(Color("b4f6ff"), 1.45)
			shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			burst.add_child(shard)
			var shard_tween := create_tween()
			shard_tween.set_parallel(true)
			shard_tween.tween_property(shard, "position", Vector3(cos(angle) * 0.38, 0.02, sin(angle) * 0.38), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			shard_tween.tween_property(shard, "scale", Vector3.ZERO, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if kind == "Ankan":
		for i in range(3):
			var angle := TAU * float(i) / 3.0
			var arc_start := position + Vector3(0.0, 0.42, 0.0)
			var arc_end := position + Vector3(cos(angle) * 0.42, 0.60, sin(angle) * 0.42)
			_spawn_electric_arc(arc_start, arc_end)
	if kind == "Cannon":
		var flare := MeshInstance3D.new()
		var flare_mesh := SphereMesh.new()
		flare_mesh.radius = 0.2
		flare_mesh.height = 0.4
		flare_mesh.radial_segments = 7
		flare_mesh.rings = 4
		flare.mesh = flare_mesh
		flare.scale = Vector3(0.55, 0.78, 0.55)
		var flare_material := _glow_mat(Color("ffb24f"), 2.6)
		flare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flare.material_override = flare_material
		burst.add_child(flare)
		var flare_tween := create_tween()
		flare_tween.set_parallel(true)
		flare_tween.tween_property(flare, "scale", Vector3(1.75, 1.2, 1.75), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flare_tween.tween_property(flare_material, "albedo_color:a", 0.0, 0.22)
		var smoke := _make_impact_particles(Color(0.28, 0.30, 0.27, 0.42), 7, 0.62)
		smoke.spread = 28.0
		smoke.gravity = Vector3(0.0, 0.35, 0.0)
		smoke.scale_amount_min = 0.11
		smoke.scale_amount_max = 0.19
		smoke.position.y = 0.10
		burst.add_child(smoke)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.12
	ring_mesh.outer_radius = 0.24
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.scale = Vector3.ONE * 0.2
	var ring_material := _glow_mat(color, 1.2)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_material
	burst.add_child(ring)
	var spark_material := _glow_mat(color.lightened(0.24), 1.8)
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.055
		spark_mesh.height = 0.11
		spark_mesh.radial_segments = 9
		spark_mesh.rings = 6
		spark.mesh = spark_mesh
		spark.position = Vector3(cos(angle) * 0.1, 0.08, sin(angle) * 0.1)
		spark.material_override = spark_material
		burst.add_child(spark)
		create_tween().tween_property(spark, "position", Vector3(cos(angle) * 0.42, 0.10, sin(angle) * 0.42), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(spark, "scale", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.7, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.28)
	tween.chain().tween_interval(0.42)
	tween.tween_callback(burst.queue_free)

func _make_impact_particles(color: Color, particle_count: int, speed: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = particle_count
	particles.lifetime = 0.56
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.12
	particles.direction = Vector3(0.0, 0.9, 0.0)
	particles.spread = 68.0
	particles.gravity = Vector3(0.0, -3.8, 0.0)
	particles.initial_velocity_min = speed * 0.45
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.045
	particles.scale_amount_max = 0.105
	particles.color = color
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.055
	particle_mesh.height = 0.11
	particle_mesh.radial_segments = 8
	particle_mesh.rings = 5
	var particle_material := _glow_mat(color, 1.4)
	if color.a < 0.8:
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mesh.material = particle_material
	particles.mesh = particle_mesh
	particles.emitting = true
	return particles

func _spawn_electric_arc(start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var sideways := direction.cross(Vector3.UP).normalized()
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT
	var vertical := direction.cross(sideways).normalized()
	var arc_mesh := ImmediateMesh.new()
	var arc_material := _glow_mat(Color("dba7ff"), 3.4)
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_material.albedo_color.a = 0.95
	arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES, arc_material)
	var previous := start
	for i in range(1, 8):
		var t := float(i) / 7.0
		var offset := Vector3.ZERO
		if i < 7:
			offset = sideways * randf_range(-0.18, 0.18) + vertical * randf_range(-0.13, 0.13)
		var point := finish if i == 7 else start.lerp(finish, t) + offset
		arc_mesh.surface_add_vertex(previous)
		arc_mesh.surface_add_vertex(point)
		previous = point
	arc_mesh.surface_end()
	var arc := MeshInstance3D.new()
	arc.mesh = arc_mesh
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(arc)
	var tween := create_tween()
	tween.tween_property(arc_material, "albedo_color:a", 0.0, 0.16)
	tween.tween_callback(arc.queue_free)

func _hit_enemy(target: Node3D, kind: String, damage: int = 1) -> void:
	var impact_offset := Vector3.ZERO
	for candidate in enemies:
		if candidate.node == target and candidate.get("is_boss", false):
			impact_offset = Vector3.UP * 0.95
			break
	_spawn_impact_vfx(target.position + impact_offset, kind)
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if enemy.node != target:
			continue
		if kind == "Frost":
			enemy.slow_timer = 1.6
			enemies[i] = enemy
		if kind == "Cannon":
			var impact := target.position
			for nearby in range(enemies.size() - 1, -1, -1):
				if enemies[nearby].node.position.distance_to(impact) <= 1.2:
					_damage_enemy(nearby, damage)
		elif kind == "Ankan":
			var impact := target.position
			var chain_targets: Array[Node3D] = []
			for candidate in enemies:
				if candidate.node != target and candidate.node.position.distance_to(impact) <= 1.7:
					chain_targets.append(candidate.node)
					if chain_targets.size() == 2:
						break
			_damage_enemy(i, damage)
			for chain_target in chain_targets:
				_spawn_electric_arc(impact + Vector3.UP * 0.48, chain_target.position + Vector3.UP * 0.48)
				_damage_enemy_node(chain_target, damage)
		else:
			_damage_enemy(i, damage)
		return

func _damage_enemy(index: int, damage: int = 1) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	enemy.hp -= damage
	enemy.hit_flash = 0.14
	if enemy.hp <= 0:
		enemy.node.queue_free()
		enemies.remove_at(index)
		gold += 80 if enemy.get("is_boss", false) else 12
		if enemy.get("is_boss", false):
			message_label.text = "MiangBoss defeated! +80 coins!"
		_update_hud()
	else:
		_animate_enemy_hp_bar(enemy)
		enemies[index] = enemy

func _damage_enemy_node(target: Node3D, damage: int = 1) -> void:
	for i in range(enemies.size()):
		if enemies[i].node == target:
			_damage_enemy(i, damage)
			return

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_resolve_skill_check()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating_camera = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning_camera = event.pressed
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size * 0.9, 8.0, 18.0)
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size * 1.1, 8.0, 18.0)
			return
	if event is InputEventMouseMotion:
		if rotating_camera:
			camera_yaw -= event.relative.x * 0.006
			camera_pitch = clampf(camera_pitch + event.relative.y * 0.005, 0.48, 1.2)
			_update_camera_transform()
			return
		if panning_camera:
			var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
			var world_per_pixel := camera.size / viewport_height
			var camera_right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
			var camera_up := Vector3(camera.global_basis.y.x, 0.0, camera.global_basis.y.z).normalized()
			camera_focus -= camera_right * event.relative.x * world_per_pixel
			camera_focus += camera_up * event.relative.y * world_per_pixel
			camera_focus.x = clampf(camera_focus.x, -3.0, 3.0)
			camera_focus.z = clampf(camera_focus.z, -2.0, 2.0)
			_update_camera_transform()
			return
		_update_build_range_preview(event.position)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset_camera()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if game_over:
		return
	var origin := camera.project_ray_origin(event.position)
	var direction := camera.project_ray_normal(event.position)
	if abs(direction.y) < 0.001:
		return
	var tower_index := _pick_tower(origin, direction)
	if tower_index >= 0:
		_show_tower_actions(towers[tower_index])
		return
	var hit := origin + direction * ((0.49-origin.y)/direction.y)
	var cell := Vector2i(floor(hit.x + W*0.5), floor(hit.z + H*0.5))
	if not (cell in PADS):
		tower_action_panel.visible = false
		selected_placed_cell = Vector2i(-1, -1)
		_clear_placement_ghost()
		if range_preview:
			range_preview.visible = false
		return
	if tower_cells.has(cell):
		var existing_index := _tower_index_for_cell(cell)
		if existing_index >= 0:
			_show_tower_actions(towers[existing_index])
		return
	tower_action_panel.visible = false
	var config: Dictionary = _tower_config(selected_tower)
	if gold < config.cost:
		message_label.text = "You need %d coins to build a %s tower." % [config.cost, selected_tower]
		return
	var pos := _cell_pos(cell)
	var visual_start := world_root.get_child_count()
	var visual: Dictionary = _build_tower_visual(pos, selected_tower)
	var visual_nodes := world_root.get_children().slice(visual_start)
	var record := {"cell":cell,"x":pos.x,"z":pos.y,"kind":selected_tower,"range":config.range,"rate":config.rate,"damage":1,"level":1,"cooldown":0.25,"empowered":false,"arm_timer":0.0,"aim_node":visual.get("aim_node"),"arm_pivot":visual.get("arm_pivot"),"recoil_node":visual.get("recoil_node"),"core_node":visual.get("core_node"),"visual_nodes":visual_nodes}
	towers.append(record)
	tower_cells[cell] = true
	gold -= config.cost
	_update_hud()
	message_label.text = "%s tower built. %s" % [selected_tower, config.description]
	_show_tower_actions(towers.back())
	if range_preview:
		range_preview.visible = false

func _pick_tower(origin: Vector3, direction: Vector3) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(towers.size()):
		var tower: Dictionary = towers[i]
		var center_y := 1.2 if tower.kind == "Ankan" else 1.0
		var center := Vector3(tower.x,center_y,tower.z)
		var along_ray := (center - origin).dot(direction)
		if along_ray <= 0.0:
			continue
		var nearest_point := origin + direction * along_ray
		var radius := 0.78 if tower.kind == "Ankan" else 0.62
		if nearest_point.distance_to(center) <= radius and along_ray < best_distance:
			best_index = i
			best_distance = along_ray
	return best_index

func _tower_index_for_cell(cell: Vector2i) -> int:
	for i in range(towers.size()):
		if towers[i].cell == cell:
			return i
	return -1

func _show_tower_actions(tower: Dictionary) -> void:
	_clear_placement_ghost()
	selected_placed_cell = tower.cell
	tower_action_panel.visible = true
	tower_info_label.text = "%s - Level %d\nDamage %d  |  Coverage range: %.1f tiles" % [tower.kind,tower.level,tower.damage,tower.range]
	upgrade_tower_button.disabled = gold < 100
	_show_range_coverage(Vector2(tower.x, tower.z), tower.range)

func _selected_tower_index() -> int:
	if selected_placed_cell.x < 0:
		return -1
	return _tower_index_for_cell(selected_placed_cell)

func _upgrade_selected_tower() -> void:
	var index := _selected_tower_index()
	if index < 0:
		tower_action_panel.visible = false
		return
	if gold < 100:
		message_label.text = "You need 100 gold to upgrade this tower."
		return
	var tower: Dictionary = towers[index]
	tower.level += 1
	tower.damage += 1
	tower.range *= 1.12
	tower.rate = maxf(0.35,tower.rate * 0.9)
	towers[index] = tower
	gold -= 100
	_update_hud()
	_show_tower_actions(tower)
	message_label.text = "%s upgraded to level %d." % [tower.kind,tower.level]

func _remove_selected_tower() -> void:
	var index := _selected_tower_index()
	if index < 0:
		tower_action_panel.visible = false
		return
	var tower: Dictionary = towers[index]
	for node in tower.visual_nodes:
		if is_instance_valid(node):
			node.queue_free()
	tower_cells.erase(tower.cell)
	towers.remove_at(index)
	selected_placed_cell = Vector2i(-1,-1)
	tower_action_panel.visible = false
	if range_preview:
		range_preview.visible = false
	message_label.text = "%s tower removed." % tower.kind

func _build_tower_visual(pos: Vector2, kind: String) -> Dictionary:
	var custom_model: PackedScene
	match kind:
		"Cannon":
			custom_model = cannon_tower_model
		"Frost":
			custom_model = frost_tower_model
		"Ankan":
			custom_model = ankan_tower_model
		_:
			custom_model = ranger_tower_model
	if custom_model:
		var model := custom_model.instantiate() as Node3D
		if model:
			_improve_imported_materials(model)
			if kind == "Ankan":
				# This GLB is Z-up; convert it to Godot's Y-up orientation and remove its showcase plinth.
				model.rotation.x = -PI / 2.0
				model.scale = Vector3.ONE * 0.42
				_remove_named_nodes(model, "DisplayGround")
				_tone_down_ankan_materials(model)
				var aim_node := Node3D.new()
				aim_node.name = "AnkanAim"
				aim_node.position = Vector3(pos.x,0.52,pos.y)
				var path_direction := _nearest_path_direction(pos)
				if path_direction.length_squared() > 0.001:
					aim_node.rotation.y = atan2(path_direction.x,path_direction.y)
				world_root.add_child(aim_node)
				model.position = Vector3.ZERO
				aim_node.add_child(model)
				var arm_pivot := _make_attack_arm_pivot(model)
				return {"aim_node":aim_node,"arm_pivot":arm_pivot}
			var rig := _prepare_tower_aim(model, kind)
			_add_tower_model_details(model, kind)
			model.position = Vector3(pos.x,0.5,pos.y)
			world_root.add_child(model)
			return rig
	_box(Vector3(0.72,0.28,0.72),Color("80513c"),Vector3(pos.x,0.64,pos.y),6)
	match kind:
		"Cannon":
			_box(Vector3(0.50,0.38,0.50),Color("66564a"),Vector3(pos.x,0.98,pos.y),6)
			var barrel := _box(Vector3(0.30,0.66,0.30),Color("55575a"),Vector3(pos.x,1.28,pos.y),6)
			barrel.rotation.x = PI/2
			_box(Vector3(0.36,0.12,0.36),Color("303b43"),Vector3(pos.x,1.28,pos.y-0.30),6)
		"Frost":
			_box(Vector3(0.48,0.46,0.48),Color("548c98"),Vector3(pos.x,0.98,pos.y),6)
			var crystal := MeshInstance3D.new()
			var crystal_mesh := SphereMesh.new()
			crystal_mesh.radius = 0.36
			crystal_mesh.height = 0.9
			crystal_mesh.radial_segments = 5
			crystal_mesh.rings = 2
			crystal.mesh = crystal_mesh
			crystal.position = Vector3(pos.x,1.48,pos.y)
			crystal.rotation.z = 0.18
			crystal.material_override = _glow_mat(Color("66dcf4"),0.8)
			world_root.add_child(crystal)
			_box(Vector3(0.12,0.34,0.12),Color("b1f5ff"),Vector3(pos.x,1.80,pos.y),6)
		_:
			_box(Vector3(0.48,0.72,0.48),Color("c6e9e4"),Vector3(pos.x,1.08,pos.y),6)
			var cap := MeshInstance3D.new()
			var cap_mesh := SphereMesh.new()
			cap_mesh.radius = 0.34
			cap_mesh.height = 0.52
			cap_mesh.radial_segments = 6
			cap_mesh.rings = 3
			cap.mesh = cap_mesh
			cap.scale.y = 0.75
			cap.position = Vector3(pos.x,1.62,pos.y)
			cap.material_override = _mat(Color("65b6d0"))
			world_root.add_child(cap)
	return {}

func _add_tower_model_details(model: Node3D, kind: String) -> void:
	var aim_parent := model.get_node_or_null("AimPivot") as Node3D
	var upper: Node3D = aim_parent if aim_parent else model
	var trim := MeshInstance3D.new()
	var trim_mesh := TorusMesh.new()
	trim_mesh.inner_radius = 0.31
	trim_mesh.outer_radius = 0.37
	trim_mesh.rings = 10
	trim_mesh.ring_segments = 6
	trim.mesh = trim_mesh
	trim.rotation.x = PI * 0.5
	trim.position.y = 0.18
	trim.material_override = _mat(Color("d0a45f"))
	model.add_child(trim)
	match kind:
		"Ranger":
			_add_model_gem(upper, Vector3(0,0.82,-0.22) if aim_parent else Vector3(0,1.50,-0.22), Color("8ae8f2"), 0.11)
		"Cannon":
			var muzzle_trim := MeshInstance3D.new()
			var muzzle_mesh := TorusMesh.new()
			muzzle_mesh.inner_radius = 0.12
			muzzle_mesh.outer_radius = 0.19
			muzzle_mesh.rings = 8
			muzzle_mesh.ring_segments = 6
			muzzle_trim.mesh = muzzle_mesh
			muzzle_trim.rotation.x = PI * 0.5
			muzzle_trim.position = Vector3(0,0.21,-0.94) if aim_parent else Vector3(0,0.61,-0.94)
			muzzle_trim.material_override = _mat(Color("c79a58"))
			upper.add_child(muzzle_trim)
		"Frost":
			var halo := MeshInstance3D.new()
			var halo_mesh := TorusMesh.new()
			halo_mesh.inner_radius = 0.36
			halo_mesh.outer_radius = 0.41
			halo_mesh.rings = 10
			halo_mesh.ring_segments = 6
			halo.mesh = halo_mesh
			halo.rotation.x = PI * 0.5
			halo.position.y = 0.52 if aim_parent else 0.94
			halo.material_override = _glow_mat(Color("75dff2"), 0.75)
			upper.add_child(halo)

func _prepare_tower_aim(model: Node3D, kind: String) -> Dictionary:
	var pivot_height := 0.5
	var parts: Array[String] = []
	match kind:
		"Ranger":
			pivot_height = 0.68
			parts = ["WoodPlatform", "TowerBody", "BlueHelmet", "Visor"]
		"Cannon":
			pivot_height = 0.40
			parts = ["Turret", "Barrel", "Muzzle"]
		"Frost":
			pivot_height = 0.42
			parts = ["CrystalCore", "LeftShard", "RightShard"]
	var pivot := Node3D.new()
	pivot.name = "AimPivot"
	pivot.position.y = pivot_height
	model.add_child(pivot)
	var recoil_node: Node3D
	var core_node: Node3D
	for part_name in parts:
		var part := model.get_node_or_null(NodePath(part_name)) as Node3D
		if not part:
			continue
		var saved_transform := part.transform
		model.remove_child(part)
		pivot.add_child(part)
		part.transform = saved_transform
		part.position.y -= pivot_height
		if kind == "Cannon" and part_name == "Barrel":
			recoil_node = part
		if kind == "Frost" and part_name == "CrystalCore":
			core_node = part
	return {"aim_node": pivot, "recoil_node": recoil_node, "core_node": core_node}

func _animate_tower_fire(tower: Dictionary, kind: String) -> void:
	var motion_node: Variant = tower.get("recoil_node", null) if kind == "Cannon" else tower.get("core_node", null)
	if not is_instance_valid(motion_node) or not motion_node is Node3D:
		return
	var node := motion_node as Node3D
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if kind == "Cannon":
		var original_z: float = node.position.z
		tween.tween_property(node, "position:z", original_z + 0.12, 0.055)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position:z", original_z, 0.12)
	else:
		var original_scale: Vector3 = node.scale
		tween.tween_property(node, "scale", original_scale * 1.14, 0.08)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", original_scale, 0.16)

func _add_model_gem(parent: Node3D, local_position: Vector3, color: Color, radius: float) -> void:
	var gem := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = radius
	gem_mesh.height = radius * 2.0
	gem_mesh.radial_segments = 6
	gem_mesh.rings = 3
	gem.mesh = gem_mesh
	gem.position = local_position
	gem.material_override = _glow_mat(color, 1.0)
	parent.add_child(gem)

func _tone_down_ankan_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if not source:
					continue
				var muted := source.duplicate() as StandardMaterial3D
				# Lower brightness and blend vivid colors toward a calm, darker neutral.
				muted.albedo_color = source.albedo_color.lerp(Color("55594f"), 0.28) * Color(0.78, 0.78, 0.78, 1.0)
				if muted.emission_enabled:
					muted.emission_energy_multiplier *= 0.55
				mesh_instance.set_surface_override_material(surface, muted)
	for child in node.get_children():
		_tone_down_ankan_materials(child)

func _make_attack_arm_pivot(model: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "AttackArmPivot"
	pivot.position = Vector3(0.62,0,1.42)
	model.add_child(pivot)
	for part_name in ["RightJacket", "RightArm", "RightHand"]:
		var part := model.get_node_or_null(part_name) as Node3D
		if part:
			model.remove_child(part)
			pivot.add_child(part)
			part.position = -pivot.position
	return pivot

func _update_hud() -> void:
	if gold_label:
		gold_label.text = "🪙  %d" % gold
		lives_label.text = "❤️  %d" % lives
		wave_label.text = "Wave  %d" % wave
	if upgrade_tower_button and tower_action_panel and tower_action_panel.visible:
		upgrade_tower_button.disabled = gold < 100
