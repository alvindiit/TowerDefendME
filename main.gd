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

@export_group("Environment GLB Replacements")
@export var environment_outcrop_asset: PackedScene
@export var environment_rock_cluster_asset: PackedScene
@export var environment_vegetation_asset: PackedScene
@export var environment_grass_asset: PackedScene
@export var environment_debris_asset: PackedScene

@export_group("Terrain PBR Texture Maps")
@export var terrain_texture_scale := 2.8
@export var terrain_grass_albedo: Texture2D
@export var terrain_grass_normal: Texture2D
@export var terrain_grass_orm: Texture2D
@export var terrain_rock_albedo: Texture2D
@export var terrain_rock_normal: Texture2D
@export var terrain_rock_orm: Texture2D
@export var terrain_dirt_albedo: Texture2D
@export var terrain_dirt_normal: Texture2D
@export var terrain_dirt_orm: Texture2D
@export var terrain_mud_albedo: Texture2D
@export var terrain_mud_normal: Texture2D
@export var terrain_mud_orm: Texture2D

const ROCK_MODEL_PATHS := [
	"res://environment/rocks/rock_01.glb",
	"res://environment/rocks/rock_02.glb",
	"res://environment/rocks/rock_03.glb",
	"res://environment/rocks/rock_04.glb",
	"res://environment/rocks/rock_05.glb",
	"res://environment/rocks/rock_06.glb",
]

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
var smoke_texture_cache: Texture2D
var smoke_fade_cache: Gradient
var vegetation_mesh_variants: Array[Mesh] = []
var vegetation_instance_transforms: Dictionary = {}
var environment_structure_variants: Array[PackedScene] = []
var rock_instance_transforms: Dictionary = {}
var rock_mesh_variants: Array[Mesh] = []
var _terrain_decal_transforms: Dictionary = {"dust": [], "scorch": [], "track": [], "footprint": []}
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
				if enemy.roar_elapsed >= 0.82 and not enemy.roar_landing_shaken:
					enemy.roar_landing_shaken = true
					_trigger_boss_landing_vfx(p)
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
		var arc_height: float = shot.get("arc_height", 0.35)
		shot.node.position = shot.start.lerp(finish, progress) + Vector3.UP * sin(progress * PI) * arc_height
		var flight_direction: Vector3 = finish - shot.node.position + Vector3.UP * cos(progress * PI) * arc_height * PI
		if flight_direction.length_squared() > 0.001:
			shot.node.look_at(shot.node.position + flight_direction, Vector3.UP)
		if shot.life <= 0.0:
			if is_instance_valid(shot.target):
				_hit_enemy(shot.target, shot.tower_kind, shot.damage)
			var projectile_trail := shot.node.get_node_or_null("ProjectileTrail") as CPUParticles3D
			if projectile_trail and is_instance_valid(projectile_trail):
				projectile_trail.reparent(world_root, true)
				projectile_trail.emitting = false
				get_tree().create_timer(projectile_trail.lifetime).timeout.connect(projectile_trail.queue_free)
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
	env.background_color = Color("171b1c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4eadc")
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.48
	env.glow_bloom = 0.055
	env.ssao_enabled = true
	env.ssao_radius = 0.62
	env.ssao_intensity = 0.38
	env.ssao_power = 1.2
	env.ssao_detail = 0.58
	env.ssil_enabled = true
	env.ssil_radius = 2.4
	env.ssil_intensity = 0.3
	env.ssil_sharpness = 0.84
	env.fog_enabled = true
	env.fog_light_color = Color("34302f")
	env.fog_density = 0.005
	env.fog_sun_scatter = 0.18
	world.environment = env
	world_root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.shadow_enabled = true
	light.light_color = Color("fff4df")
	light.light_energy = 2.25
	light.shadow_blur = 0.32
	light.shadow_bias = 0.025
	light.shadow_normal_bias = 0.48
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = 42.0
	light.directional_shadow_blend_splits = true
	world_root.add_child(light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.0, 5.0, -1.0)
	fill_light.light_color = Color("aebdad")
	fill_light.light_energy = 0.62
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
	_build_continuous_terrain()
	_build_vegetation_library()
	for z in range(H):
		for x in range(W):
			var cell := Vector2i(x,z)
			var p := _cell_pos(cell)
			if not route_set.has(cell) and not (cell in PADS) and (x * 5 + z * 7) % 9 == 0:
				_add_meadow_rock(p, 0.55 + float((x + z) % 4) * 0.08)
			elif not route_set.has(cell) and not (cell in PADS) and (x * 3 + z * 5) % 12 == 0:
				_add_meadow_bush(p, 0.65 + float((x + z) % 3) * 0.1)
			elif not route_set.has(cell) and not (cell in PADS) and (x * 11 + z * 7) % 4 == 0:
				_add_grass_tuft(p, 0.72 + float((x + z) % 4) * 0.08)
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = 512947
	for i in range(46):
		var detail_position := Vector2(detail_rng.randf_range(-5.45, 5.45), detail_rng.randf_range(-3.45, 3.45))
		if _distance_to_route(detail_position) > 0.78 and _distance_to_pads(detail_position) > 0.76:
			_add_grass_tuft(detail_position, detail_rng.randf_range(0.48, 0.88))
	for i in range(24):
		var stone_position := Vector2(detail_rng.randf_range(-5.4, 5.4), detail_rng.randf_range(-3.4, 3.4))
		if _distance_to_route(stone_position) > 0.72 and _distance_to_pads(stone_position) > 0.74:
			_add_meadow_rock(stone_position, detail_rng.randf_range(0.35, 0.68))
	_place_natural_vegetation_clusters(detail_rng)
	_build_instanced_environment_scatter()
	_add_terrain_decals()
	# Basalt outcrops frame the board without changing the tile layout.
	for data in [[0,0,0.85],[3,0,0.7],[6,0,0.8],[11,1,0.85],[0,6,0.8],[1,7,0.95],[6,7,0.8],[11,7,0.9],[9,0,0.75]]:
		_add_rock_outcrop(int(data[0]), int(data[1]), float(data[2]))
	_build_environment_structure_variants()
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

func _build_continuous_terrain() -> void:
	const SUBDIVISIONS_PER_CELL := 24
	var x_segments := W * SUBDIVISIONS_PER_CELL
	var z_segments := H * SUBDIVISIONS_PER_CELL
	var vertices: Array[Vector3] = []
	var vertex_normals: Array[Vector3] = []
	var vertex_colors: Array[Color] = []
	var vertex_uvs: Array[Vector2] = []
	vertices.resize((x_segments + 1) * (z_segments + 1))
	vertex_normals.resize(vertices.size())
	vertex_colors.resize(vertices.size())
	vertex_uvs.resize(vertices.size())
	for z_index in range(z_segments + 1):
		for x_index in range(x_segments + 1):
			var x := -float(W) * 0.5 + float(x_index) / float(SUBDIVISIONS_PER_CELL)
			var z := -float(H) * 0.5 + float(z_index) / float(SUBDIVISIONS_PER_CELL)
			if x_index == 0:
				x += 0.12 + sin(z * 1.75) * 0.075 + sin(z * 3.1 + 0.8) * 0.025
			elif x_index == x_segments:
				x -= 0.12 + sin(z * 1.62 + 1.4) * 0.075 + sin(z * 2.9) * 0.025
			if z_index == 0:
				z += 0.12 + sin(x * 1.48 + 1.8) * 0.075 + sin(x * 2.6) * 0.025
			elif z_index == z_segments:
				z -= 0.12 + sin(x * 1.67) * 0.075 + sin(x * 3.0 + 0.4) * 0.025
			var point := Vector2(x, z)
			var route_mask := _terrain_mask(_distance_to_route(point), 0.39, 0.73)
			var pad_mask := _terrain_mask(_distance_to_pads(point), 0.35, 0.63)
			var ground_height := _terrain_landform_height(point)
			var route_point := _nearest_terrain_route_point(point)
			var road_height := _terrain_landform_height(route_point) - 0.28
			var height := lerpf(ground_height, road_height, route_mask)
			height = lerpf(height, 0.51, pad_mask)
			var moss_noise := 0.5 + 0.5 * sin(x * 1.43 + sin(z * 1.9) * 1.6) * cos(z * 0.94 - x * 0.36)
			var moss_mask := _terrain_mask(1.0 - moss_noise, 0.28, 0.62) * (1.0 - route_mask) * (1.0 - pad_mask)
			var vertex_index := z_index * (x_segments + 1) + x_index
			vertices[vertex_index] = Vector3(x, height, z)
			vertex_colors[vertex_index] = Color(route_mask, moss_mask, pad_mask, 1.0)
			vertex_uvs[vertex_index] = Vector2(x, z)
	# Accumulate area-weighted face normals so neighboring triangles share smooth vertex normals.
	for z_index in range(z_segments):
		for x_index in range(x_segments):
			var a := z_index * (x_segments + 1) + x_index
			var b := a + 1
			var c := a + x_segments + 1
			var d := c + 1
			var first_face_normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			var second_face_normal := (vertices[c] - vertices[b]).cross(vertices[d] - vertices[b])
			vertex_normals[a] += first_face_normal
			vertex_normals[c] += first_face_normal
			vertex_normals[b] += first_face_normal
			vertex_normals[b] += second_face_normal
			vertex_normals[c] += second_face_normal
			vertex_normals[d] += second_face_normal
	for vertex_index in range(vertex_normals.size()):
		vertex_normals[vertex_index] = vertex_normals[vertex_index].normalized()
	var top_surface := SurfaceTool.new()
	top_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(z_segments):
		for x_index in range(x_segments):
			var a := z_index * (x_segments + 1) + x_index
			var b := a + 1
			var c := a + x_segments + 1
			var d := c + 1
			_add_terrain_triangle(top_surface, vertices, vertex_normals, vertex_colors, vertex_uvs, a, c, b)
			_add_terrain_triangle(top_surface, vertices, vertex_normals, vertex_colors, vertex_uvs, b, c, d)
	top_surface.index()
	top_surface.generate_tangents()
	top_surface.set_material(_terrain_material(Color("30382f"), 3))
	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "ContinuousTerrainSurface"
	terrain_instance.mesh = top_surface.commit()
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	world_root.add_child(terrain_instance)
	var boundary: Array[Dictionary] = []
	for x_index in range(x_segments + 1):
		boundary.append({"vertex": x_index, "outward": Vector2(0.0, -1.0)})
	for z_index in range(1, z_segments + 1):
		boundary.append({"vertex": z_index * (x_segments + 1) + x_segments, "outward": Vector2(1.0, 0.0)})
	for x_index in range(x_segments - 1, -1, -1):
		boundary.append({"vertex": z_segments * (x_segments + 1) + x_index, "outward": Vector2(0.0, 1.0)})
	for z_index in range(z_segments - 1, 0, -1):
		boundary.append({"vertex": z_index * (x_segments + 1), "outward": Vector2(-1.0, 0.0)})
	_add_terrain_cliffs(boundary, vertices, vertex_uvs)

func _add_terrain_triangle(surface: SurfaceTool, vertices: Array[Vector3], normals: Array[Vector3], colors: Array[Color], uvs: Array[Vector2], a: int, b: int, c: int) -> void:
	surface.set_smooth_group(0)
	surface.set_color(colors[a])
	surface.set_normal(normals[a])
	surface.set_uv(uvs[a])
	surface.add_vertex(vertices[a])
	surface.set_color(colors[b])
	surface.set_normal(normals[b])
	surface.set_uv(uvs[b])
	surface.add_vertex(vertices[b])
	surface.set_color(colors[c])
	surface.set_normal(normals[c])
	surface.set_uv(uvs[c])
	surface.add_vertex(vertices[c])

func _add_terrain_cliffs(boundary: Array[Dictionary], vertices: Array[Vector3], uvs: Array[Vector2]) -> void:
	var cliffs := SurfaceTool.new()
	cliffs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(boundary.size()):
		var current: Dictionary = boundary[i]
		var next: Dictionary = boundary[(i + 1) % boundary.size()]
		var current_index: int = int(current["vertex"])
		var next_index: int = int(next["vertex"])
		var current_pos: Vector3 = vertices[current_index]
		var next_pos: Vector3 = vertices[next_index]
		var current_normal: Vector2 = current["outward"]
		var next_normal: Vector2 = next["outward"]
		for layer in range(5):
			var layer_top := float(layer) * 0.38 + sin(float(i) * 0.21 + float(layer)) * 0.045
			var layer_bottom := float(layer + 1) * 0.38 + sin(float(i + 1) * 0.18 + float(layer) * 1.7) * 0.055
			var top_inset := float(layer) * 0.035
			var lower_inset := 0.07 + float(layer) * 0.055 + sin(float(i) * 0.31 + float(layer)) * 0.025
			var top_a := current_pos + Vector3(current_normal.x * top_inset, -layer_top, current_normal.y * top_inset)
			var top_b := next_pos + Vector3(next_normal.x * top_inset, -layer_top, next_normal.y * top_inset)
			var lower_a := current_pos + Vector3(current_normal.x * lower_inset, -layer_bottom, current_normal.y * lower_inset)
			var lower_b := next_pos + Vector3(next_normal.x * lower_inset, -layer_bottom, next_normal.y * lower_inset)
			var stratum_shade := 0.78 + float((i + layer * 3) % 5) * 0.045
			var cliff_color := Color(0.0, 0.0, 0.0, stratum_shade)
			_add_cliff_triangle(cliffs, top_a, lower_a, top_b, cliff_color, uvs[current_index], uvs[current_index] + Vector2(0.0, 0.4), uvs[next_index])
			_add_cliff_triangle(cliffs, top_b, lower_a, lower_b, cliff_color, uvs[next_index], uvs[current_index] + Vector2(0.0, 0.4), uvs[next_index] + Vector2(0.0, 0.4))
	cliffs.index()
	cliffs.generate_normals()
	cliffs.set_material(_terrain_material(Color("303337"), 4))
	var cliff_instance := MeshInstance3D.new()
	cliff_instance.name = "NaturalTerrainCliffs"
	cliff_instance.mesh = cliffs.commit()
	cliff_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	world_root.add_child(cliff_instance)

func _add_cliff_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_smooth_group(-1)
	surface.set_color(color)
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_smooth_group(-1)
	surface.set_color(color)
	surface.set_uv(uv_c)
	surface.add_vertex(c)

func _distance_to_route(point: Vector2) -> float:
	var nearest_distance_squared := INF
	for i in range(ROUTE.size() - 1):
		var start := _cell_pos(ROUTE[i])
		var finish := _cell_pos(ROUTE[i + 1])
		var segment := finish - start
		var length_squared := segment.length_squared()
		var progress := clampf((point - start).dot(segment) / maxf(length_squared, 0.001), 0.0, 1.0)
		nearest_distance_squared = minf(nearest_distance_squared, point.distance_squared_to(start + segment * progress))
	return sqrt(nearest_distance_squared)

func _distance_to_pads(point: Vector2) -> float:
	var nearest_distance_squared := INF
	for cell in PADS:
		nearest_distance_squared = minf(nearest_distance_squared, point.distance_squared_to(_cell_pos(cell)))
	return sqrt(nearest_distance_squared)

func _terrain_mask(distance: float, inner_radius: float, outer_radius: float) -> float:
	var t := clampf((distance - inner_radius) / maxf(outer_radius - inner_radius, 0.001), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)

func _nearest_terrain_route_point(point: Vector2) -> Vector2:
	var nearest_point := _cell_pos(ROUTE[0])
	var nearest_distance_squared := INF
	for i in range(ROUTE.size() - 1):
		var start := _cell_pos(ROUTE[i])
		var finish := _cell_pos(ROUTE[i + 1])
		var segment := finish - start
		var progress := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var candidate := start + segment * progress
		var distance_squared := point.distance_squared_to(candidate)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_point = candidate
	return nearest_point

func _terrain_landform_height(point: Vector2) -> float:
	var x := point.x
	var z := point.y
	var broad_roll := sin(x * 0.57 + sin(z * 0.63) * 0.8) * cos(z * 0.71 - x * 0.28)
	var cross_roll := sin(z * 0.44 + x * 0.37 + 1.2) * 0.5
	var ridge_a_center := 0.75 + sin(x * 0.48 + 0.4) * 1.25
	var ridge_a := exp(-pow(z - ridge_a_center, 2.0) * 1.55) * 0.68
	var ridge_b_center := 2.25 + sin(z * 0.62 - 0.8) * 0.52
	var ridge_b := exp(-pow(x - ridge_b_center, 2.0) * 2.1) * 0.54
	var ridge_c_center := -3.0 + sin(x * 0.36 + 1.8) * 0.72
	var ridge_c := exp(-pow(z - ridge_c_center, 2.0) * 2.4) * 0.38
	var basin_a := exp(-pow((x + 2.2) / 1.3, 2.0) - pow((z - 0.45) / 1.0, 2.0)) * 0.48
	var basin_b := exp(-pow((x - 1.0) / 1.15, 2.0) - pow((z + 2.25) / 0.85, 2.0)) * 0.36
	var eroded_surface := sin(x * 1.7 + z * 1.15) * cos(z * 2.05 - x * 0.72) * 0.055
	var original_height := clampf(0.52 + broad_roll * 0.27 + cross_roll * 0.16 + ridge_a + ridge_b + ridge_c - basin_a - basin_b + eroded_surface, 0.035, 2.05)
	# Keep the broad center playable and gently rolling while blending smoothly to
	# the untouched outer landform. This only affects the visible terrain height field.
	var center_distance := Vector2(x / 5.5, z / 3.5).length()
	var blend_progress := clampf((center_distance - 0.84) / 0.16, 0.0, 1.0)
	var center_flatten_weight := 1.0 - blend_progress * blend_progress * (3.0 - 2.0 * blend_progress)
	var flattened_height := 0.52 + (original_height - 0.52) * 0.30
	return lerpf(original_height, flattened_height, center_flatten_weight)

func _add_rock_outcrop(x: int, z: int, scale: float) -> void:
	var pos := _cell_pos(Vector2i(x, z))
	var ground_height := _sample_terrain_height(pos)
	if _add_environment_asset(environment_outcrop_asset, world_root, Vector3(pos.x, ground_height, pos.y), Vector3.ONE * scale, float(x + z) * 0.31):
		return
	if rock_mesh_variants.is_empty():
		_build_rock_mesh_variants()
	if rock_mesh_variants.is_empty():
		return
	var outcrop := Node3D.new()
	outcrop.position = Vector3(pos.x, ground_height, pos.y)
	outcrop.scale = Vector3.ONE * scale
	world_root.add_child(outcrop)
	var main_variant := posmod(x * 7 + z * 11, rock_mesh_variants.size())
	_add_rock_mesh_instance(outcrop, main_variant, Vector3(0.0, 0.0, 0.0), Vector3(1.22, 1.0, 1.18), float(x + z) * 0.4, "MainRock")
	for i in range(2):
		var variant := posmod(main_variant + i + 1, rock_mesh_variants.size())
		var side_offset := Vector3(-0.34 if i == 0 else 0.36, 0.0, 0.12 if i == 0 else -0.13)
		var side_scale := Vector3(0.68, 0.65, 0.72) if i == 0 else Vector3(0.58, 0.78, 0.64)
		_add_rock_mesh_instance(outcrop, variant, side_offset, side_scale, float(x * 3 + z + i) * 0.83, "Boulder%d" % i)
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
	var ground_height := _sample_terrain_height(pos)
	if _add_environment_asset(environment_debris_asset, world_root, Vector3(pos.x, ground_height, pos.y), Vector3.ONE, float((cell.x * 3 + cell.y) % 4) * PI * 0.25):
		return
	if environment_structure_variants.is_empty():
		_build_environment_structure_variants()
	if environment_structure_variants.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(cell.x * 7919 + cell.y * 1049 + 2647))
	var variant := rng.randi_range(0, environment_structure_variants.size() - 1)
	var structure := environment_structure_variants[variant].instantiate() as Node3D
	structure.name = "EnvironmentStructure_%02d_%d_%d" % [variant + 1, cell.x, cell.y]
	structure.position = Vector3(pos.x, ground_height, pos.y)
	structure.rotation.y = rng.randf_range(0.0, TAU)
	var structure_scale := rng.randf_range(0.88, 1.02)
	structure.scale = Vector3(structure_scale * rng.randf_range(0.96, 1.04), structure_scale, structure_scale * rng.randf_range(0.96, 1.04))
	world_root.add_child(structure)

func _build_environment_structure_variants() -> void:
	environment_structure_variants.clear()
	for variant in range(6):
		var root := Node3D.new()
		root.name = "Structure%02d" % (variant + 1)
		_create_environment_structure(root, variant)
		_set_structure_owners(root, root)
		var packed := PackedScene.new()
		var pack_result := packed.pack(root)
		if pack_result == OK:
			environment_structure_variants.append(packed)
		else:
			push_error("Could not pack environment structure variant %d" % variant)
		root.free()

func _set_structure_owners(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_set_structure_owners(child, scene_root)

func _create_environment_structure(root: Node3D, variant: int) -> void:
	var body_colors: Array[Color] = [Color("48504c"), Color("66513e"), Color("505750"), Color("4b5555"), Color("575148"), Color("574a3e")]
	var roof_colors: Array[Color] = [Color("303c3a"), Color("493b32"), Color("3f4845"), Color("364447"), Color("47433c"), Color("43372f")]
	var wood_colors: Array[Color] = [Color("755740"), Color("876345"), Color("72533b"), Color("66513c"), Color("70553d"), Color("8a6849")]
	var stone_colors: Array[Color] = [Color("555952"), Color("665e50"), Color("535850"), Color("59605e"), Color("5f584e"), Color("62564a")]
	var metal_colors: Array[Color] = [Color("59615d"), Color("5d5b54"), Color("63645d"), Color("566267"), Color("5c5953"), Color("5c5852")]
	var wall_material := _structure_material(body_colors[variant], 0.86, 0.0)
	var roof_material := _structure_material(roof_colors[variant], 0.78, 0.34)
	var wood_material := _structure_material(wood_colors[variant], 0.88, 0.0)
	var stone_material := _structure_material(stone_colors[variant], 0.93, 0.0)
	var metal_material := _structure_material(metal_colors[variant], 0.76, 0.48)
	var dark_material := _structure_material(Color("262c2a"), 0.9, 0.0)
	var glass_material := _structure_material(Color("354847"), 0.32, 0.16)
	var trim_material := _structure_material(Color("332f29"), 0.88, 0.0)
	var handle_material := _structure_material(Color("b89a64"), 0.72, 0.12) if variant == 1 or variant == 5 else metal_material
	_add_structure_box(root, Vector3(0.86, 0.16, 0.78), Vector3(0.0, 0.08, 0.0), stone_material, Vector3.ZERO, "StoneFoundation")
	for side in [-1.0, 1.0]:
		_add_structure_box(root, Vector3(0.055, 0.78, 0.065), Vector3(side * 0.38, 0.45, -0.345), wood_material, Vector3.ZERO, "FrontCornerPost")
		_add_structure_box(root, Vector3(0.055, 0.78, 0.065), Vector3(side * 0.38, 0.45, 0.345), wood_material, Vector3.ZERO, "RearCornerPost")
	if variant == 4:
		_add_structure_box(root, Vector3(0.24, 0.56, 0.68), Vector3(-0.25, 0.43, 0.0), stone_material, Vector3(0.0, 0.0, -0.025), "RuinedLeftWall")
		_add_structure_box(root, Vector3(0.28, 0.34, 0.68), Vector3(0.23, 0.32, 0.0), wall_material, Vector3.ZERO, "RuinedRightWall")
		_add_structure_box(root, Vector3(0.40, 0.12, 0.68), Vector3(-0.01, 0.70, 0.0), wood_material, Vector3.ZERO, "BrokenLintel")
	else:
		_add_structure_box(root, Vector3(0.76, 0.58, 0.68), Vector3(0.0, 0.42, 0.0), wall_material, Vector3.ZERO, "MainWalls")
	_add_structure_gable(root, -0.345, wall_material)
	_add_structure_gable(root, 0.345, wall_material)
	_add_structure_box(root, Vector3(0.30, 0.47, 0.035), Vector3(0.0, 0.32, -0.363), dark_material, Vector3.ZERO, "RecessedDoorway")
	_add_structure_box(root, Vector3(0.25, 0.43, 0.025), Vector3(0.0, 0.30, -0.386), wood_material if variant == 1 or variant == 5 else metal_material, Vector3.ZERO, "Door")
	_add_structure_box(root, Vector3(0.045, 0.48, 0.05), Vector3(-0.17, 0.31, -0.385), trim_material, Vector3.ZERO, "DoorFrame")
	_add_structure_box(root, Vector3(0.045, 0.48, 0.05), Vector3(0.17, 0.31, -0.385), trim_material, Vector3.ZERO, "DoorFrame")
	_add_structure_box(root, Vector3(0.38, 0.055, 0.05), Vector3(0.0, 0.56, -0.385), trim_material, Vector3.ZERO, "DoorHeader")
	_add_structure_box(root, Vector3(0.026, 0.026, 0.022), Vector3(0.085, 0.30, -0.405), handle_material, Vector3.ZERO, "DoorHandle")
	if variant != 2 and variant != 4:
		for side in [-1.0, 1.0]:
			var window_x: float = float(side) * 0.255
			_add_structure_box(root, Vector3(0.15, 0.17, 0.025), Vector3(window_x, 0.57, -0.363), glass_material, Vector3.ZERO, "WindowGlass")
			_add_structure_box(root, Vector3(0.19, 0.035, 0.045), Vector3(window_x, 0.675, -0.37), wood_material, Vector3.ZERO, "WindowLintel")
			_add_structure_box(root, Vector3(0.025, 0.19, 0.045), Vector3(window_x, 0.57, -0.37), trim_material, Vector3.ZERO, "WindowMullion")
		_add_structure_box(root, Vector3(0.82, 0.065, 0.82), Vector3(0.0, 0.77, 0.0), trim_material, Vector3.ZERO, "EaveBeam")
	if variant == 3:
		_add_structure_box(root, Vector3(0.22, 0.27, 0.055), Vector3(0.22, 0.38, 0.371), metal_material, Vector3.ZERO, "SideVentHousing")
		for slot in range(4):
			_add_structure_box(root, Vector3(0.17, 0.018, 0.07), Vector3(0.22, 0.30 + float(slot) * 0.055, 0.405), dark_material, Vector3.ZERO, "VentSlot")
		_add_structure_box(root, Vector3(0.045, 0.30, 0.045), Vector3(-0.37, 0.48, 0.16), metal_material, Vector3(0.08, 0.0, -0.06), "UtilityPipe")
	elif variant == 1 or variant == 5:
		for plank in range(4):
			_add_structure_box(root, Vector3(0.42, 0.045, 0.025), Vector3(0.0, 0.12 + float(plank) * 0.11, -0.408), wood_material, Vector3.ZERO, "FrontTimberPlank")
	elif variant == 2:
		_add_structure_box(root, Vector3(0.56, 0.055, 0.035), Vector3(0.02, 0.34, -0.407), wood_material, Vector3(0.0, 0.0, 0.48), "DamagedBoard")
		_add_structure_box(root, Vector3(0.05, 0.34, 0.05), Vector3(0.34, 0.51, -0.30), trim_material, Vector3(0.0, 0.0, -0.18), "BrokenBeam")
	elif variant == 0:
		_add_structure_box(root, Vector3(0.32, 0.19, 0.035), Vector3(0.0, 0.57, 0.366), metal_material, Vector3.ZERO, "RearServicePanel")
		for slot in range(3):
			_add_structure_box(root, Vector3(0.24, 0.018, 0.045), Vector3(0.0, 0.53 + float(slot) * 0.055, 0.392), dark_material, Vector3.ZERO, "PanelSlot")
	_add_structure_box(root, Vector3(0.56, 0.055, 0.055), Vector3(0.0, 1.03, 0.0), trim_material, Vector3.ZERO, "RidgeCap")
	if variant == 3:
		_add_structure_roof_piece(root, Vector3(0.94, 0.09, 0.90), Vector3(0.0, 0.92, 0.0), Vector3(0.0, 0.0, 0.08), roof_material, "LeanToRoof")
	else:
		_add_structure_roof_piece(root, Vector3(0.56, 0.085, 0.84), Vector3(-0.245, 0.91, 0.0), Vector3(0.0, 0.0, 0.53), roof_material, "LeftRoofSlope")
		if variant != 4:
			_add_structure_roof_piece(root, Vector3(0.56, 0.085, 0.84), Vector3(0.245, 0.91, 0.0), Vector3(0.0, 0.0, -0.53), roof_material, "RightRoofSlope")
		for rib in range(5):
			var x := -0.39 + float(rib) * 0.195
			if variant == 4 and rib > 2:
				continue
			var left_side := x < 0.0
			var rib_rotation := 0.53 if left_side else -0.53
			var roof_x := x
			_add_structure_roof_piece(root, Vector3(0.026, 0.035, 0.76), Vector3(roof_x, 0.91 + (0.245 - absf(x)) * 0.59, 0.0), Vector3(0.0, 0.0, rib_rotation), metal_material, "RoofRib")
	for corner_x in [-0.31, 0.31]:
		for corner_z in [-0.29, 0.29]:
			_add_structure_box(root, Vector3(0.035, 0.035, 0.035), Vector3(corner_x, 0.18, corner_z), metal_material, Vector3.ZERO, "FoundationAnchor")

func _structure_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = 0.3
	return material

func _add_structure_box(parent: Node3D, size: Vector3, position: Vector3, material: Material, rotation: Vector3, node_name: String) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box.mesh = box_mesh
	box.position = position
	box.rotation = rotation
	box.material_override = material
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	box.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(box)
	return box

func _add_structure_roof_piece(parent: Node3D, size: Vector3, position: Vector3, rotation: Vector3, material: Material, node_name: String) -> void:
	_add_structure_box(parent, size, position, material, rotation, node_name)

func _add_structure_gable(parent: Node3D, z_position: float, material: Material) -> void:
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	gable.set_smooth_group(-1)
	gable.set_color(Color.WHITE)
	if z_position < 0.0:
		gable.add_vertex(Vector3(-0.38, 0.71, z_position))
		gable.add_vertex(Vector3(0.0, 1.08, z_position))
		gable.add_vertex(Vector3(0.38, 0.71, z_position))
	else:
		gable.add_vertex(Vector3(-0.38, 0.71, z_position))
		gable.add_vertex(Vector3(0.38, 0.71, z_position))
		gable.add_vertex(Vector3(0.0, 1.08, z_position))
	gable.generate_normals()
	var gable_instance := MeshInstance3D.new()
	gable_instance.name = "GableWall"
	gable_instance.mesh = gable.commit()
	gable_instance.material_override = material
	gable_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(gable_instance)

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
	enemy.roar_landing_shaken = false
	enemy.roar_delay = 5.0
	enemy.roar_speed_timer = 1.0
	camera_shake_duration = 0.9
	camera_shake_timer = camera_shake_duration
	camera_shake_strength = 0.24
	enemy.speech_bubble = _show_boss_speech(enemy.node)
	message_label.text = "MiangBoss roars and jumps! The ground shakes beneath it!"

func _trigger_boss_landing_vfx(position: Vector2) -> void:
	camera_shake_duration = 0.62
	camera_shake_timer = camera_shake_duration
	camera_shake_strength = 0.34
	_spawn_boss_landing_dust(Vector3(position.x, 0.08, position.y))

func _spawn_boss_landing_dust(position: Vector3) -> void:
	var impact := Node3D.new()
	impact.position = position
	world_root.add_child(impact)
	var dust := _make_impact_particles(Color(0.34, 0.30, 0.24, 0.50), 18, 2.1)
	dust.lifetime = 0.62
	dust.emission_sphere_radius = 0.24
	dust.scale_amount_min = 0.16
	dust.scale_amount_max = 0.42
	dust.gravity = Vector3(0.0, -1.1, 0.0)
	impact.add_child(dust)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.49
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.scale = Vector3(0.45, 0.45, 0.45)
	var ring_material := _mat(Color("82745d"))
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color.a = 0.48
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	impact.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.45, 1.45, 1.45), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.38)
	tween.chain().tween_interval(0.28)
	tween.tween_callback(impact.queue_free)

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
			return {"cost":0,"range":4.0,"rate":1.45,"description":"Slow shots splash nearby enemies."}
		"Frost":
			return {"cost":0,"range":3.1,"rate":0.95,"description":"Icy shots slow enemies for a short time."}
		"Ankan":
			return {"cost":0,"range":4.0,"rate":1.05,"description":"Purple bolts jump to nearby enemies."}
		_:
			return {"cost":0,"range":3.4,"rate":0.72,"description":"Fast shots hit one enemy."}

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
	render_mode cull_disabled;
	uniform vec4 base_color : source_color = vec4(0.19, 0.23, 0.19, 1.0);
	uniform vec4 path_color : source_color = vec4(0.27, 0.20, 0.14, 1.0);
	uniform vec4 pad_color : source_color = vec4(0.20, 0.15, 0.11, 1.0);
	uniform float texture_scale = 2.8;
	uniform int surface_kind = 0;
	uniform bool has_grass_albedo = false;
	uniform bool has_grass_normal = false;
	uniform bool has_grass_orm = false;
	uniform bool has_rock_albedo = false;
	uniform bool has_rock_normal = false;
	uniform bool has_rock_orm = false;
	uniform bool has_dirt_albedo = false;
	uniform bool has_dirt_normal = false;
	uniform bool has_dirt_orm = false;
	uniform bool has_mud_albedo = false;
	uniform bool has_mud_normal = false;
	uniform bool has_mud_orm = false;
	uniform sampler2D grass_albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D grass_normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D grass_orm_texture : repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D rock_albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D rock_normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D rock_orm_texture : repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D dirt_albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D dirt_normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D dirt_orm_texture : repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D mud_albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D mud_normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
	uniform sampler2D mud_orm_texture : repeat_enable, filter_linear_mipmap_anisotropic;
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
		vec2 p = UV * texture_scale;
		float broad = noise_value(p * 0.23);
		float grain = noise_value(p * 1.8);
		vec3 rock_color = has_rock_albedo ? texture(rock_albedo_texture, p).rgb : base_color.rgb;
		vec3 grass_color = has_grass_albedo ? texture(grass_albedo_texture, p).rgb : base_color.rgb * vec3(0.62, 0.92, 0.57);
		vec3 dirt_color = has_dirt_albedo ? texture(dirt_albedo_texture, p).rgb : path_color.rgb;
		vec3 mud_color = has_mud_albedo ? texture(mud_albedo_texture, p * 0.72).rgb : path_color.rgb * vec3(0.64, 0.70, 0.72);
		float road_mask = surface_kind == 3 ? COLOR.r : 0.0;
		float moss_mask = surface_kind == 3 ? COLOR.g : 0.0;
		float pad_mask = surface_kind == 3 ? COLOR.b : 0.0;
		float mud_noise = smoothstep(0.58, 0.83, noise_value(p * 0.62 + vec2(8.1, 3.7))) * road_mask;
		vec3 color = mix(rock_color, grass_color, moss_mask);
		color = mix(color, dirt_color, road_mask * (1.0 - mud_noise * 0.78));
		color = mix(color, mud_color, mud_noise * 0.78);
		color = mix(color, pad_color.rgb * (0.82 + broad * 0.18), pad_mask);
		float crack = smoothstep(0.82, 0.97, noise_value(p * 2.4 + vec2(4.2, 1.7)));
		if (surface_kind == 4) {
			color = rock_color * (0.70 + broad * 0.30 + grain * 0.12) * COLOR.a;
			color = mix(color, color * vec3(0.62, 0.65, 0.66), crack * 0.40);
		} else {
			color *= 0.70 + broad * 0.28 + grain * 0.16;
			color = mix(color, color * vec3(0.54, 0.56, 0.55), crack * 0.26);
		}
		vec3 rock_normal = normalize((has_rock_normal ? texture(rock_normal_texture, p).rgb : vec3(0.5, 0.5, 1.0)) * 2.0 - 1.0);
		vec3 grass_normal = normalize((has_grass_normal ? texture(grass_normal_texture, p).rgb : vec3(0.5, 0.5, 1.0)) * 2.0 - 1.0);
		vec3 dirt_normal = normalize((has_dirt_normal ? texture(dirt_normal_texture, p).rgb : vec3(0.5, 0.5, 1.0)) * 2.0 - 1.0);
		vec3 mud_normal = normalize((has_mud_normal ? texture(mud_normal_texture, p * 0.72).rgb : vec3(0.5, 0.5, 1.0)) * 2.0 - 1.0);
		vec3 blended_normal = normalize(mix(mix(rock_normal, grass_normal, moss_mask), dirt_normal, road_mask * (1.0 - mud_noise * 0.78)));
		blended_normal = normalize(mix(blended_normal, mud_normal, mud_noise * 0.78));
		float bump_x = noise_value((p + vec2(0.018, 0.0)) * 3.2) - noise_value((p - vec2(0.018, 0.0)) * 3.2);
		float bump_y = noise_value((p + vec2(0.0, 0.018)) * 3.2) - noise_value((p - vec2(0.0, 0.018)) * 3.2);
		vec3 procedural_normal = normalize(vec3(-bump_x * 5.0, -bump_y * 5.0, 1.0));
		blended_normal = normalize(mix(blended_normal, procedural_normal, 0.30));
		vec3 pad_normal = mix(blended_normal, rock_normal, pad_mask);
		vec3 rock_orm = has_rock_orm ? texture(rock_orm_texture, p).rgb : vec3(0.82, 0.92, 0.0);
		vec3 grass_orm = has_grass_orm ? texture(grass_orm_texture, p).rgb : vec3(0.78, 0.96, 0.0);
		vec3 dirt_orm = has_dirt_orm ? texture(dirt_orm_texture, p).rgb : vec3(0.80, 0.94, 0.0);
		vec3 mud_orm = has_mud_orm ? texture(mud_orm_texture, p * 0.72).rgb : vec3(0.74, 0.70, 0.0);
		vec3 blended_orm = mix(mix(rock_orm, grass_orm, moss_mask), dirt_orm, road_mask * (1.0 - mud_noise * 0.78));
		blended_orm = mix(blended_orm, mud_orm, mud_noise * 0.78);
		blended_orm = mix(blended_orm, rock_orm, pad_mask);
		if (surface_kind == 4) {
			pad_normal = rock_normal;
			blended_orm = rock_orm;
		}
		ALBEDO = color;
		NORMAL_MAP = pad_normal * 0.5 + 0.5;
		ROUGHNESS = clamp(blended_orm.g + (grain - 0.5) * 0.16, 0.42, 1.0);
		METALLIC = min(blended_orm.b, 0.12);
		AO = clamp(blended_orm.r * (0.82 + broad * 0.18), 0.0, 1.0);
		SPECULAR = 0.22;
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = terrain_shader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("surface_kind", surface_kind)
	material.set_shader_parameter("path_color", Color("594633"))
	material.set_shader_parameter("pad_color", Color("392f25"))
	material.set_shader_parameter("texture_scale", terrain_texture_scale)
	_set_terrain_texture(material, "grass_albedo_texture", "has_grass_albedo", terrain_grass_albedo)
	_set_terrain_texture(material, "grass_normal_texture", "has_grass_normal", terrain_grass_normal)
	_set_terrain_texture(material, "grass_orm_texture", "has_grass_orm", terrain_grass_orm)
	_set_terrain_texture(material, "rock_albedo_texture", "has_rock_albedo", terrain_rock_albedo)
	_set_terrain_texture(material, "rock_normal_texture", "has_rock_normal", terrain_rock_normal)
	_set_terrain_texture(material, "rock_orm_texture", "has_rock_orm", terrain_rock_orm)
	_set_terrain_texture(material, "dirt_albedo_texture", "has_dirt_albedo", terrain_dirt_albedo)
	_set_terrain_texture(material, "dirt_normal_texture", "has_dirt_normal", terrain_dirt_normal)
	_set_terrain_texture(material, "dirt_orm_texture", "has_dirt_orm", terrain_dirt_orm)
	_set_terrain_texture(material, "mud_albedo_texture", "has_mud_albedo", terrain_mud_albedo)
	_set_terrain_texture(material, "mud_normal_texture", "has_mud_normal", terrain_mud_normal)
	_set_terrain_texture(material, "mud_orm_texture", "has_mud_orm", terrain_mud_orm)
	terrain_material_cache[cache_key] = material
	return material

func _set_terrain_texture(material: ShaderMaterial, texture_parameter: String, enabled_parameter: String, texture: Texture2D) -> void:
	material.set_shader_parameter(enabled_parameter, texture != null)
	if texture:
		material.set_shader_parameter(texture_parameter, texture)

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
	var rock_position := Vector2(pos.x + 0.25, pos.y + 0.23)
	if _add_environment_asset(environment_rock_cluster_asset, world_root, Vector3(rock_position.x, _sample_terrain_height(rock_position) - 0.025, rock_position.y), Vector3.ONE * scale, float(pos.x + pos.y) * 0.47):
		return
	if rock_mesh_variants.is_empty():
		_build_rock_mesh_variants()
	if rock_mesh_variants.is_empty():
		return
	var ground_height := _sample_terrain_height(rock_position)
	for i in range(3):
		var offset := Vector2(float(i - 1) * 0.15 * scale, float(i % 2) * 0.10 * scale)
		var variant := posmod(int(abs(pos.x * 13.0 + pos.y * 7.0)) + i, rock_mesh_variants.size())
		var pebble_scale: float = scale * [0.26, 0.20, 0.16][i]
		var pebble_basis := Basis.from_euler(Vector3(0.11 * float(i), float(i) * 0.55, -0.08 * float(i))).scaled(Vector3.ONE * pebble_scale)
		var transform := Transform3D(pebble_basis, Vector3(rock_position.x + offset.x, ground_height - 0.035 * pebble_scale, rock_position.y + offset.y))
		if not rock_instance_transforms.has(variant):
			rock_instance_transforms[variant] = []
		(rock_instance_transforms[variant] as Array).append(transform)

func _build_vegetation_library() -> void:
	vegetation_mesh_variants.clear()
	vegetation_instance_transforms.clear()
	for variant in range(5):
		vegetation_mesh_variants.append(_create_vegetation_mesh(0, variant))
	for variant in range(3):
		vegetation_mesh_variants.append(_create_vegetation_mesh(1, variant))
	for variant in range(3):
		vegetation_mesh_variants.append(_create_vegetation_mesh(2, variant))
	for variant in range(2):
		vegetation_mesh_variants.append(_create_vegetation_mesh(3, variant))

func _create_vegetation_mesh(kind: int, variant: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319 + kind * 193 + variant * 977
	var foliage_tones: Array[Color] = [
		Color("405b39"), Color("4c6740"), Color("52683f"), Color("3d5639"), Color("5c7047"),
		Color("46633e"), Color("587348"), Color("3e5b3d"), Color("354d35"), Color("40583a"),
		Color("49613c"), Color("566846"), Color("475b3b")
	]
	var base_color: Color = foliage_tones[posmod(kind * 4 + variant, foliage_tones.size())]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	if kind == 0:
		var blade_count := 14 + variant * 2
		for blade in range(blade_count):
			var angle := TAU * float(blade) / float(blade_count) + rng.randf_range(-0.16, 0.16)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var direction := Vector3(radial.x * rng.randf_range(0.26, 0.46), rng.randf_range(0.72, 1.0), radial.z * rng.randf_range(0.26, 0.46))
			var start := Vector3(radial.x * rng.randf_range(0.015, 0.07), 0.0, radial.z * rng.randf_range(0.015, 0.07))
			_append_3d_leaf(surface, start, direction, rng.randf_range(0.31, 0.53) + float(variant) * 0.018, rng.randf_range(0.024, 0.045), base_color.lightened(rng.randf_range(0.0, 0.08)), 0.07)
	elif kind == 1:
		var leaf_count := 7 + variant * 2
		for leaf in range(leaf_count):
			var angle := TAU * float(leaf) / float(leaf_count) + rng.randf_range(-0.18, 0.18)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var direction := Vector3(radial.x * rng.randf_range(0.46, 0.72), rng.randf_range(0.62, 1.05), radial.z * rng.randf_range(0.46, 0.72))
			var start := Vector3(radial.x * 0.025, rng.randf_range(0.0, 0.045), radial.z * 0.025)
			_append_3d_leaf(surface, start, direction, rng.randf_range(0.28, 0.47), rng.randf_range(0.065, 0.105), base_color.lightened(rng.randf_range(0.0, 0.10)), 0.06)
	elif kind == 2:
		var leaf_count := 24 + variant * 5
		for leaf in range(leaf_count):
			var angle := TAU * float(leaf) * 0.6180339 + float(variant) * 0.37
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var start := Vector3(radial.x * rng.randf_range(0.04, 0.20), rng.randf_range(0.08, 0.34), radial.z * rng.randf_range(0.04, 0.20))
			var direction := Vector3(radial.x * rng.randf_range(0.48, 0.86), rng.randf_range(-0.12, 0.52), radial.z * rng.randf_range(0.48, 0.86))
			_append_3d_leaf(surface, start, direction, rng.randf_range(0.20, 0.36), rng.randf_range(0.085, 0.14), base_color.lightened(rng.randf_range(0.0, 0.07)), 0.035)
	else:
		var leaf_count := 5 + variant * 2
		for leaf in range(leaf_count):
			var angle := TAU * float(leaf) / float(leaf_count) + rng.randf_range(-0.2, 0.2)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var direction := Vector3(radial.x * rng.randf_range(0.38, 0.68), rng.randf_range(0.38, 0.72), radial.z * rng.randf_range(0.38, 0.68))
			var start := Vector3(radial.x * 0.018, 0.0, radial.z * 0.018)
			_append_3d_leaf(surface, start, direction, rng.randf_range(0.14, 0.25), rng.randf_range(0.045, 0.075), base_color.lightened(rng.randf_range(0.0, 0.08)), 0.025)
	surface.index()
	surface.generate_normals()
	var foliage_mesh := surface.commit()
	var foliage_material := StandardMaterial3D.new()
	foliage_material.albedo_color = base_color.lightened(0.48)
	foliage_material.vertex_color_use_as_albedo = true
	foliage_material.metallic = 0.0
	foliage_material.roughness = 0.88
	foliage_material.metallic_specular = 0.24
	foliage_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage_material.emission_enabled = false
	foliage_mesh.surface_set_material(0, foliage_material)
	return foliage_mesh

func _append_3d_leaf(surface: SurfaceTool, start: Vector3, direction: Vector3, length: float, width: float, color: Color, arch: float) -> void:
	var forward := direction.normalized()
	var lateral := forward.cross(Vector3.UP).normalized()
	if lateral.length_squared() < 0.001:
		lateral = Vector3.RIGHT
	var sections: Array[float] = [0.0, 0.28, 0.62, 0.86, 1.0]
	var width_profile: Array[float] = [0.06, 0.72, 1.0, 0.62, 0.03]
	var left_points: Array[Vector3] = []
	var ridge_points: Array[Vector3] = []
	var right_points: Array[Vector3] = []
	var lower_points: Array[Vector3] = []
	for section in range(sections.size()):
		var t := sections[section]
		var center := start + forward * length * t + Vector3.UP * sin(t * PI) * arch
		var half_width := width * width_profile[section]
		left_points.append(center - lateral * half_width)
		right_points.append(center + lateral * half_width)
		ridge_points.append(center + Vector3.UP * half_width * 0.22)
		lower_points.append(center - Vector3.UP * width * 0.10)
	for section in range(sections.size() - 1):
		var shade := 0.94 + sections[section] * 0.12
		var leaf_color := color * shade
		_append_vegetation_triangle(surface, left_points[section], ridge_points[section], left_points[section + 1], leaf_color)
		_append_vegetation_triangle(surface, ridge_points[section], ridge_points[section + 1], left_points[section + 1], leaf_color.lightened(0.035))
		_append_vegetation_triangle(surface, ridge_points[section], right_points[section], ridge_points[section + 1], leaf_color.lightened(0.06))
		_append_vegetation_triangle(surface, right_points[section], right_points[section + 1], ridge_points[section + 1], leaf_color)
		_append_vegetation_triangle(surface, lower_points[section], lower_points[section + 1], left_points[section + 1], color.darkened(0.06))
		_append_vegetation_triangle(surface, lower_points[section], left_points[section + 1], left_points[section], color.darkened(0.06))
		_append_vegetation_triangle(surface, lower_points[section], right_points[section + 1], lower_points[section + 1], color.darkened(0.06))
		_append_vegetation_triangle(surface, lower_points[section], right_points[section], right_points[section + 1], color.darkened(0.06))

func _append_vegetation_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.add_vertex(c)

func _place_natural_vegetation_clusters(rng: RandomNumberGenerator) -> void:
	for patch in range(28):
		var center: Vector2
		if patch % 4 == 0:
			var route_cell: Vector2i = ROUTE[rng.randi_range(0, ROUTE.size() - 1)]
			var route_center := _cell_pos(route_cell)
			var edge_angle := rng.randf_range(-PI, PI)
			center = route_center + Vector2(cos(edge_angle), sin(edge_angle)) * rng.randf_range(0.85, 1.45)
		else:
			center = Vector2(rng.randf_range(-5.3, 5.3), rng.randf_range(-3.3, 3.3))
		var cluster_radius := rng.randf_range(0.28, 0.75)
		var cluster_kind := rng.randi_range(0, 3)
		var members := rng.randi_range(4, 8)
		for member in range(members):
			var point := center + Vector2(rng.randfn(0.0, cluster_radius * 0.48), rng.randfn(0.0, cluster_radius * 0.48))
			if absf(point.x) > 5.45 or absf(point.y) > 3.45:
				continue
			if _distance_to_route(point) < 0.70 or _distance_to_pads(point) < 0.88:
				continue
			var variant := 0
			var size := 1.0
			match cluster_kind:
				0:
					variant = rng.randi_range(0, 4)
					size = rng.randf_range(0.58, 1.12)
				1:
					variant = 5 + rng.randi_range(0, 2)
					size = rng.randf_range(0.58, 0.98)
				2:
					variant = 8 + rng.randi_range(0, 2)
					size = rng.randf_range(0.64, 1.08)
				_:
					variant = 11 + rng.randi_range(0, 1)
					size = rng.randf_range(0.55, 0.9)
			var yaw := rng.randf_range(-PI, PI)
			var scale := Vector3(size * rng.randf_range(0.86, 1.18), size, size * rng.randf_range(0.86, 1.18))
			_queue_vegetation_instance(variant, point, scale, yaw)

func _queue_vegetation_instance(variant: int, point: Vector2, scale: Vector3, yaw: float) -> void:
	if variant < 0 or variant >= vegetation_mesh_variants.size():
		return
	if _distance_to_route(point) < 0.66 or _distance_to_pads(point) < 0.84:
		return
	var ground_height := _sample_terrain_height(point)
	var pitch := sin(point.x * 4.3 + point.y * 3.1) * 0.045
	var roll := cos(point.x * 2.7 - point.y * 4.8) * 0.045
	var basis := Basis.from_euler(Vector3(pitch, yaw, roll)).scaled(scale)
	var transform := Transform3D(basis, Vector3(point.x, ground_height + 0.003, point.y))
	if not vegetation_instance_transforms.has(variant):
		vegetation_instance_transforms[variant] = []
	(vegetation_instance_transforms[variant] as Array).append(transform)

func _add_meadow_bush(pos: Vector2, scale: float) -> void:
	var bush_position := Vector2(pos.x - 0.25, pos.y + 0.24)
	if _distance_to_route(bush_position) < 0.66 or _distance_to_pads(bush_position) < 0.84:
		return
	var ground_height := _sample_terrain_height(bush_position)
	if _add_environment_asset(environment_vegetation_asset, world_root, Vector3(bush_position.x, ground_height, bush_position.y), Vector3.ONE * scale, float(pos.x - pos.y) * 0.36):
		return
	var variant := posmod(int(abs(pos.x * 7.0 + pos.y * 11.0)), 3)
	_queue_vegetation_instance(8 + variant, bush_position, Vector3.ONE * scale, float(pos.x * 3.1 + pos.y * 1.7))

func _add_grass_tuft(pos: Vector2, scale: float) -> void:
	var tuft_position := Vector2(pos.x + 0.22, pos.y - 0.18)
	if _distance_to_route(tuft_position) < 0.66 or _distance_to_pads(tuft_position) < 0.84:
		return
	if _add_environment_asset(environment_grass_asset, world_root, Vector3(tuft_position.x, _sample_terrain_height(tuft_position) + 0.006, tuft_position.y), Vector3.ONE * scale, float(pos.x + pos.y) * 0.29):
		return
	var variant := posmod(int(abs(pos.x * 17.0 + pos.y * 13.0)), 5)
	_queue_vegetation_instance(variant, tuft_position, Vector3.ONE * scale, float(pos.x * 3.7 + pos.y * 5.1))

func _sample_terrain_height(point: Vector2) -> float:
	var route_mask := _terrain_mask(_distance_to_route(point), 0.39, 0.73)
	var pad_mask := _terrain_mask(_distance_to_pads(point), 0.35, 0.63)
	var broad_terrain := sin(point.x * 0.72 + sin(point.y * 0.58) * 0.9) * cos(point.y * 0.64 - point.x * 0.31)
	var medium_terrain := sin(point.x * 2.05 + point.y * 1.21) * cos(point.y * 1.74 - point.x * 0.83)
	var fine_terrain := sin(point.x * 4.4 + sin(point.y * 3.2)) * cos(point.y * 4.1 - point.x * 1.4)
	var ground_height := 0.51 + broad_terrain * 0.055 + medium_terrain * 0.022 + fine_terrain * 0.007
	ground_height += exp(-pow(_distance_to_route(point) - 0.83, 2.0) * 5.0) * -0.045
	ground_height *= 1.0 - pad_mask
	return lerpf(lerpf(ground_height, 0.22, route_mask), 0.51, pad_mask)

func _build_rock_mesh_variants() -> void:
	rock_mesh_variants.clear()
	var rock_tones: Array[Color] = [
		Color8(74, 75, 73), Color8(79, 76, 71), Color8(70, 74, 74),
		Color8(77, 73, 68), Color8(72, 75, 71), Color8(76, 76, 74)
	]
	for variant in range(ROCK_MODEL_PATHS.size()):
		var model_path: String = ROCK_MODEL_PATHS[variant]
		var rock_scene := load(model_path) as PackedScene
		if rock_scene == null:
			push_error("Rock asset could not be loaded: %s" % model_path)
			continue
		var rock_root := rock_scene.instantiate()
		var rock_mesh_node := _find_first_mesh(rock_root)
		var rock_mesh: Mesh = rock_mesh_node.mesh if rock_mesh_node != null else null
		rock_root.free()
		if rock_mesh == null:
			push_error("Rock asset has no mesh: %s" % model_path)
			continue
		var rock_material := StandardMaterial3D.new()
		rock_material.albedo_color = rock_tones[variant]
		rock_material.vertex_color_use_as_albedo = false
		rock_material.metallic = 0.0
		rock_material.roughness = 0.84
		rock_material.metallic_specular = 0.32
		rock_material.emission_enabled = false
		rock_mesh.surface_set_material(0, rock_material)
		rock_mesh_variants.append(rock_mesh)
func _add_rock_mesh_instance(parent: Node3D, variant: int, local_position: Vector3, local_scale: Vector3, yaw: float, instance_name: String) -> void:
	var rock := MeshInstance3D.new()
	rock.name = instance_name
	rock.mesh = rock_mesh_variants[variant]
	rock.position = local_position
	rock.scale = local_scale
	rock.rotation.y = yaw
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(rock)

func _build_instanced_environment_scatter() -> void:
	for variant in rock_instance_transforms.keys():
		var transforms: Array = rock_instance_transforms[variant]
		_add_multimesh_batch(rock_mesh_variants[int(variant)], transforms, "InstancedRockScatter%d" % int(variant), true)
	for variant in vegetation_instance_transforms.keys():
		var vegetation_transforms: Array = vegetation_instance_transforms[variant]
		var index := int(variant)
		var category := "Grass" if index < 5 else ("Plants" if index < 8 else ("Bushes" if index < 11 else "GroundCover"))
		var casts_shadow := index >= 8
		_add_multimesh_batch(vegetation_mesh_variants[index], vegetation_transforms, "Instanced%s%d" % [category, index], casts_shadow)

func _add_multimesh_batch(mesh: Mesh, transforms: Array, batch_name: String, cast_shadow: bool) -> void:
	if transforms.is_empty():
		return
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi_mesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multi_mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	world_root.add_child(instance)

func _add_terrain_decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 684203
	for i in range(48):
		var point := Vector2(rng.randf_range(-5.5, 5.5), rng.randf_range(-3.5, 3.5))
		if _distance_to_pads(point) < 0.72:
			continue
		var route_distance := _distance_to_route(point)
		var type := "dust" if route_distance > 0.72 else ("track" if i % 3 == 0 else "footprint")
		_terrain_decal_transforms[type].append(_decal_transform(point, rng.randf_range(0.28, 0.75), rng.randf_range(-PI, PI)))
	for i in range(13):
		var point := Vector2(rng.randf_range(-5.4, 5.4), rng.randf_range(-3.4, 3.4))
		if _distance_to_route(point) < 0.85 or _distance_to_pads(point) < 0.72:
			continue
		_terrain_decal_transforms["scorch"].append(_decal_transform(point, rng.randf_range(0.3, 0.62), rng.randf_range(-PI, PI)))
	for kind in _terrain_decal_transforms.keys():
		var transforms: Array = _terrain_decal_transforms[kind]
		if transforms.is_empty():
			continue
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		plane.subdivide_width = 1
		plane.subdivide_depth = 1
		plane.material = _terrain_decal_material(String(kind))
		_add_multimesh_batch(plane, transforms, "TerrainDecals_%s" % String(kind), false)

func _decal_transform(point: Vector2, size: float, yaw: float) -> Transform3D:
	var rotation := Basis.from_euler(Vector3(-PI * 0.5, yaw, 0.0)).scaled(Vector3(size, size, size))
	return Transform3D(rotation, Vector3(point.x, _sample_terrain_height(point) + 0.012, point.y))

func _terrain_decal_material(kind: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, cull_disabled, depth_draw_never;
	uniform int decal_kind = 0;
	void fragment() {
		vec2 p = UV * 2.0 - 1.0;
		float radius = length(p);
		float edge = 1.0 - smoothstep(0.45, 1.0, radius);
		float n = fract(sin(dot(floor(UV * 14.0), vec2(127.1, 311.7))) * 43758.5453);
		float alpha = edge * (0.20 + n * 0.12);
		vec3 color = vec3(0.23, 0.19, 0.14);
		if (decal_kind == 1) {
			float crack = step(0.91, fract(sin(dot(floor(UV * 26.0), vec2(47.2, 93.7))) * 24634.6));
			color = vec3(0.10, 0.09, 0.085);
			alpha *= 0.52 + crack * 0.30;
		} else if (decal_kind == 2) {
			float line_a = 1.0 - smoothstep(0.05, 0.16, abs(p.y + sin(p.x * 5.0) * 0.06));
			float line_b = 1.0 - smoothstep(0.05, 0.16, abs(p.y - 0.42 + sin(p.x * 4.0) * 0.05));
			alpha *= max(line_a, line_b) * 0.52;
			color = vec3(0.30, 0.24, 0.17);
		} else if (decal_kind == 3) {
			float left = 1.0 - smoothstep(0.10, 0.28, length(p - vec2(-0.28, 0.0)));
			float right = 1.0 - smoothstep(0.10, 0.28, length(p - vec2(0.28, 0.0)));
			alpha *= max(left, right) * 0.36;
			color = vec3(0.26, 0.20, 0.14);
		}
		ALBEDO = color;
		ALPHA = alpha;
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var kinds := {"dust": 0, "scorch": 1, "track": 2, "footprint": 3}
	material.set_shader_parameter("decal_kind", kinds[kind])
	return material

func _add_environment_asset(asset_scene: PackedScene, parent: Node3D, asset_position: Vector3, asset_scale: Vector3 = Vector3.ONE, asset_yaw: float = 0.0) -> bool:
	if not asset_scene:
		return false
	var asset := asset_scene.instantiate() as Node3D
	if not asset:
		return false
	asset.position = asset_position
	asset.scale = asset_scale
	asset.rotation.y = asset_yaw
	parent.add_child(asset)
	return true

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
	var enemy_data := {"node":enemy,"body":body,"base_color":base_color,"progress":0.0,"hp":hp,"max_hp":hp,"speed":speed,"hit_flash":0.0,"slow_timer":0.0,"is_boss":is_boss,"roar_landing_shaken":false}
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
		enemy_data.roar_landing_shaken = false
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
	var projectile_glow := 1.45 if kind == "Ranger" else (1.15 if kind == "Frost" else 1.35)
	core.material_override = _glow_mat(core_color, projectile_glow)
	bullet.add_child(core)
	var is_rocket := kind == "Cannon" or kind == "Ankan"
	var electric_arc: Node3D
	if kind == "Cannon":
		core.visible = false
		_add_rocket_projectile(bullet, core_color)
	elif kind == "Ankan":
		electric_arc = _add_ankan_projectile_vfx(bullet)
	for detail in [[0.13,core_radius*0.75,trail_color],[0.24,core_radius*0.5,tail_color]]:
		if is_rocket:
			continue
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
	streak.visible = not is_rocket
	var streak_material := _glow_mat(trail_color, 1.1)
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color.a = 0.28
	streak.material_override = streak_material
	bullet.add_child(streak)
	var projectile_trail := _make_projectile_trail(kind, trail_color)
	projectile_trail.name = "ProjectileTrail"
	bullet.add_child(projectile_trail)
	if empowered:
		bullet.scale = Vector3.ONE * 5.0
	bullet.position = start
	add_child(bullet)
	if start.distance_to(finish) > 0.01:
		bullet.look_at(finish, Vector3.UP)
	_spawn_muzzle_flash(start, core_color)
	_animate_tower_fire(tower, kind)
	var damage_multiplier := 5 if empowered else 1
	var flight_duration := 0.78 if kind == "Ankan" else 0.28
	var projectile_arc := 2.7 if kind == "Ankan" else 0.35
	shots.append({"node":bullet,"target":enemy.node,"tower_kind":kind,"damage":tower.damage * damage_multiplier,"start":start,"finish":finish,"aim_height":aim_height,"duration":flight_duration,"life":flight_duration,"arc_height":projectile_arc,"electric_arc":electric_arc})
	if empowered:
		tower.empowered = false
	tower.cooldown = tower.rate * ATTACK_INTERVAL_MULTIPLIER
	if kind == "Ankan":
		tower.arm_timer = 0.44

func _make_projectile_trail(kind: String, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 22 if kind == "Cannon" else (12 if kind == "Ankan" else 7)
	particles.lifetime = 0.46 if kind == "Cannon" else (0.34 if kind == "Ankan" else 0.22)
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.065 if kind == "Cannon" else 0.035
	particles.direction = Vector3(0.0, 0.0, 1.0)
	particles.spread = 26.0 if kind == "Cannon" else 20.0
	particles.gravity = Vector3(0.0, 0.20, 0.0) if kind == "Cannon" else Vector3.ZERO
	particles.initial_velocity_min = 0.08 if kind == "Cannon" else 0.10
	particles.initial_velocity_max = 0.34 if kind == "Cannon" else 0.30
	particles.scale_amount_min = 0.55 if kind == "Cannon" else 0.28
	particles.scale_amount_max = 1.25 if kind == "Cannon" else 0.68
	particles.color = Color(0.22, 0.23, 0.24, 0.43) if kind == "Cannon" else Color(color.r, color.g, color.b, 0.68)
	var particle_mesh: Mesh
	if kind == "Cannon":
		var smoke_quad := QuadMesh.new()
		smoke_quad.size = Vector2(0.40, 0.40)
		particle_mesh = smoke_quad
		particles.color_ramp = _get_smoke_fade()
		particle_mesh.material = _make_smoke_material(particles.color)
	else:
		var particle_sphere := SphereMesh.new()
		particle_sphere.radius = 0.025
		particle_sphere.height = 0.05
		particle_sphere.radial_segments = 9
		particle_sphere.rings = 6
		var particle_material := _glow_mat(particles.color, 1.25)
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle_material.roughness = 1.0
		particle_sphere.material = particle_material
		particle_mesh = particle_sphere
	particles.mesh = particle_mesh
	if kind == "Cannon":
		particles.position.z = 0.18
	particles.emitting = true
	return particles

func _make_smoke_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = _get_smoke_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.roughness = 1.0
	return material

func _get_smoke_texture() -> Texture2D:
	if smoke_texture_cache:
		return smoke_texture_cache
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var uv := Vector2((float(x) + 0.5) / 64.0, (float(y) + 0.5) / 64.0) * 2.0 - Vector2.ONE
			var radius := uv.length()
			var edge_phase := clampf((radius - 0.12) / 0.88, 0.0, 1.0)
			var soft_edge := 1.0 - edge_phase * edge_phase * (3.0 - 2.0 * edge_phase)
			var cloud_noise := randf_range(0.62, 1.0)
			var alpha := soft_edge * cloud_noise
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	image.generate_mipmaps()
	smoke_texture_cache = ImageTexture.create_from_image(image)
	return smoke_texture_cache

func _get_smoke_fade() -> Gradient:
	if smoke_fade_cache:
		return smoke_fade_cache
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.12, Color(1.0, 1.0, 1.0, 0.64))
	fade.add_point(0.68, Color(1.0, 1.0, 1.0, 0.34))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	smoke_fade_cache = fade
	return smoke_fade_cache

func _add_rocket_projectile(parent: Node3D, accent_color: Color) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.105
	body_mesh.height = 0.50
	body_mesh.radial_segments = 20
	body_mesh.rings = 8
	body.mesh = body_mesh
	body.rotation.x = PI * 0.5
	var body_material := _mat(Color("58646c"))
	body_material.metallic = 0.72
	body_material.roughness = 0.3
	body.material_override = body_material
	parent.add_child(body)
	var nose := MeshInstance3D.new()
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.105
	nose_mesh.height = 0.15
	nose_mesh.radial_segments = 16
	nose_mesh.rings = 10
	nose.mesh = nose_mesh
	nose.position.z = -0.24
	nose.scale = Vector3(0.72, 0.72, 1.0)
	nose.material_override = _glow_mat(accent_color.lightened(0.22), 2.2)
	parent.add_child(nose)
	for fin_index in range(4):
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.14, 0.035, 0.16)
		fin.mesh = fin_mesh
		fin.position = Vector3(cos(float(fin_index) * TAU / 4.0) * 0.105, sin(float(fin_index) * TAU / 4.0) * 0.105, 0.16)
		fin.rotation.z = float(fin_index) * TAU / 4.0
		fin.material_override = _mat(accent_color.darkened(0.24))
		parent.add_child(fin)
	var exhaust := MeshInstance3D.new()
	var exhaust_mesh := SphereMesh.new()
	exhaust_mesh.radius = 0.085
	exhaust_mesh.height = 0.34
	exhaust_mesh.radial_segments = 14
	exhaust_mesh.rings = 8
	exhaust.mesh = exhaust_mesh
	exhaust.position.z = 0.30
	exhaust.scale = Vector3(0.8, 0.8, 1.0)
	exhaust.material_override = _glow_mat(accent_color, 3.0)
	exhaust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(exhaust)

func _add_ankan_projectile_vfx(parent: Node3D) -> Node3D:
	var orbit := Node3D.new()
	orbit.name = "AnkanArcaneOrbit"
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.105 if ring_index == 0 else 0.18
		ring_mesh.outer_radius = 0.12 if ring_index == 0 else 0.193
		ring_mesh.rings = 8
		ring_mesh.ring_segments = 18
		ring.mesh = ring_mesh
		ring.rotation = Vector3(0.22 if ring_index == 0 else -0.62, 0.0, 0.0)
		var ring_color := Color("d5a5ff") if ring_index == 0 else Color("8544d1")
		ring.material_override = _glow_mat(ring_color, 1.7)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orbit.add_child(ring)
	for i in range(3):
		var mote := MeshInstance3D.new()
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.026
		mote_mesh.height = 0.052
		mote_mesh.radial_segments = 8
		mote_mesh.rings = 5
		mote.mesh = mote_mesh
		var angle := TAU * float(i) / 3.0
		mote.position = Vector3(cos(angle) * 0.16, sin(angle) * 0.13, 0.0)
		mote.material_override = _glow_mat(Color("e6caff"), 1.5)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orbit.add_child(mote)
	parent.add_child(orbit)
	return orbit

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
	burst.add_child(_make_impact_particles(color.lightened(0.18), 16 if kind == "Cannon" else 8, 2.7 if kind == "Cannon" else 2.2))
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
			shard.material_override = _glow_mat(Color("b4f6ff"), 0.85)
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
	if kind == "Cannon" or kind == "Ankan" or kind == "Frost":
		var flare := MeshInstance3D.new()
		var flare_mesh := SphereMesh.new()
		flare_mesh.radius = 0.24
		flare_mesh.height = 0.48
		flare_mesh.radial_segments = 20
		flare_mesh.rings = 12
		flare.mesh = flare_mesh
		flare.scale = Vector3(0.38, 0.48, 0.38)
		var flare_color := Color("ffad52") if kind == "Cannon" else (Color("a8eaff") if kind == "Frost" else Color("bd78ff"))
		var flare_material := _glow_mat(flare_color, 2.2 if kind == "Cannon" else 1.45)
		flare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flare.material_override = flare_material
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.add_child(flare)
		var flare_tween := create_tween()
		flare_tween.set_parallel(true)
		var flare_end_scale := Vector3(1.85, 1.25, 1.85) if kind == "Cannon" else Vector3(1.30, 1.0, 1.30)
		flare_tween.tween_property(flare, "scale", flare_end_scale, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flare_tween.tween_property(flare_material, "albedo_color:a", 0.0, 0.22)
		var flash_light := OmniLight3D.new()
		flash_light.light_color = Color("ff8a38") if kind == "Cannon" else (Color("68cfff") if kind == "Frost" else Color("9b61e8"))
		flash_light.light_energy = 1.75 if kind == "Cannon" else 0.85
		flash_light.omni_range = 2.3 if kind == "Cannon" else 1.6
		flash_light.position.y = 0.28
		burst.add_child(flash_light)
		var light_tween := create_tween()
		light_tween.tween_property(flash_light, "light_energy", 0.0, 0.20)
		light_tween.tween_callback(flash_light.queue_free)
		if kind == "Cannon":
			var smoke := _make_impact_particles(Color(0.22, 0.23, 0.24, 0.46), 16, 0.8)
			smoke.spread = 34.0
			smoke.gravity = Vector3(0.0, 0.18, 0.0)
			smoke.lifetime = 0.88
			smoke.scale_amount_min = 0.55
			smoke.scale_amount_max = 1.35
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
	var spark_count := 10 if kind == "Cannon" else (7 if kind == "Ankan" else 6)
	for i in range(spark_count):
		var angle := TAU * float(i) / float(spark_count)
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
		var spark_distance := 0.62 if kind == "Cannon" else (0.48 if kind == "Ankan" else 0.36)
		var spark_duration := 0.30 if kind == "Cannon" else (0.26 if kind == "Ankan" else 0.20)
		create_tween().tween_property(spark, "position", Vector3(cos(angle) * spark_distance, 0.10, sin(angle) * spark_distance), spark_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(spark, "scale", Vector3.ZERO, spark_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.5, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.24)
	tween.chain().tween_interval(0.78 if kind == "Cannon" else 0.18)
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
	var particle_mesh: Mesh
	if color.a < 0.8:
		var smoke_quad := QuadMesh.new()
		smoke_quad.size = Vector2(0.58, 0.58)
		particle_mesh = smoke_quad
		particles.color_ramp = _get_smoke_fade()
		particle_mesh.material = _make_smoke_material(color)
	else:
		var particle_sphere := SphereMesh.new()
		particle_sphere.radius = 0.055
		particle_sphere.height = 0.11
		particle_sphere.radial_segments = 8
		particle_sphere.rings = 5
		particle_sphere.material = _glow_mat(color, 1.4)
		particle_mesh = particle_sphere
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
	var arc_material := _glow_mat(Color("dba7ff"), 2.4)
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
			_spawn_frost_status_vfx(target)
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

func _spawn_frost_status_vfx(target: Node3D) -> void:
	if target.get_node_or_null("FrostAura"):
		return
	var aura := Node3D.new()
	aura.name = "FrostAura"
	target.add_child(aura)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.24
	ring_mesh.outer_radius = 0.29
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	ring.position.y = 0.27
	ring.rotation.x = PI * 0.5
	var ring_material := _glow_mat(Color("73dfff"), 0.55)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color.a = 0.48
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(ring)
	var shard_material := _glow_mat(Color("a6edff"), 0.7)
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.albedo_color.a = 0.72
	for i in range(3):
		var shard := MeshInstance3D.new()
		var shard_mesh := PrismMesh.new()
		shard_mesh.size = Vector3(0.09, 0.24, 0.08)
		shard.mesh = shard_mesh
		var angle := TAU * float(i) / 3.0
		shard.position = Vector3(cos(angle) * 0.28, 0.30 + float(i % 2) * 0.08, sin(angle) * 0.28)
		shard.rotation = Vector3(0.0, angle, 0.20 if i % 2 == 0 else -0.18)
		shard.scale = Vector3(0.8, 0.78, 0.8)
		shard.material_override = shard_material
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.add_child(shard)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(aura, "scale", Vector3(1.12, 1.08, 1.12), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, 1.85).set_delay(0.12)
	tween.tween_property(shard_material, "albedo_color:a", 0.0, 1.85).set_delay(0.12)
	tween.chain().tween_callback(aura.queue_free)

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
				_add_tower_laser_strip(aim_node, Vector3(-0.17,0.30,-0.12), Vector3(0.025,0.19,0.025), Color("a85df2"))
				_add_tower_laser_strip(aim_node, Vector3(0.17,0.30,-0.12), Vector3(0.025,0.19,0.025), Color("a85df2"))
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
			_add_tower_laser_strip(upper, Vector3(-0.19,0.20,-0.18), Vector3(0.025,0.16,0.025), Color("62d9ef"))
			_add_tower_laser_strip(upper, Vector3(0.19,0.20,-0.18), Vector3(0.025,0.16,0.025), Color("62d9ef"))
		"Cannon":
			var cannon_trim_material := _mat(Color("8d6334"))
			cannon_trim_material.metallic = 0.58
			cannon_trim_material.roughness = 0.55
			for side in [-1.0, 1.0]:
				var armor_inlay := MeshInstance3D.new()
				var inlay_mesh := BoxMesh.new()
				inlay_mesh.size = Vector3(0.028, 0.18, 0.035)
				armor_inlay.mesh = inlay_mesh
				armor_inlay.position = Vector3(side * 0.25, 0.04, -0.05)
				armor_inlay.material_override = cannon_trim_material
				upper.add_child(armor_inlay)
			var muzzle_trim := MeshInstance3D.new()
			var muzzle_mesh := TorusMesh.new()
			muzzle_mesh.inner_radius = 0.12
			muzzle_mesh.outer_radius = 0.19
			muzzle_mesh.rings = 8
			muzzle_mesh.ring_segments = 6
			muzzle_trim.mesh = muzzle_mesh
			muzzle_trim.rotation.x = PI * 0.5
			muzzle_trim.position = Vector3(0,0.21,-0.94) if aim_parent else Vector3(0,0.61,-0.94)
			muzzle_trim.material_override = cannon_trim_material
			upper.add_child(muzzle_trim)
		"Frost":
			_add_tower_laser_strip(model, Vector3(-0.22,0.43,-0.25), Vector3(0.025,0.20,0.025), Color("72e6ff"))
			_add_tower_laser_strip(model, Vector3(0.22,0.43,-0.25), Vector3(0.025,0.20,0.025), Color("72e6ff"))
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

func _add_tower_laser_strip(parent: Node3D, local_position: Vector3, size: Vector3, color: Color) -> void:
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = size
	strip.mesh = strip_mesh
	strip.position = local_position
	strip.material_override = _glow_mat(color, 0.82)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strip)

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
