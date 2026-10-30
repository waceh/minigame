extends Node3D
const V = preload("res://scripts/visuals.gd")
const SCENERY = preload("res://assets/forest.png")
var leaves: Array[MeshInstance3D] = []
var time := 0.0

func ground_material(grass: bool = true) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 cell=floor(world.xz*25.0);
 float a=hash(cell);float b=hash(floor(world.xz*4.0));
 vec3 grass=vec3(.15,.31,.20)*(.9+b*.2);
 grass+=vec3(.025,.035,.008)*step(.67,a);
 grass=mix(grass,vec3(.24,.39,.20),step(.96,a));
 float r=length(world.xz/vec2(6.65,3.6));
 float edge=hash(floor(world.xz*7.0))*.14;
 float clearing=1.0-smoothstep(.84+edge,1.0+edge,r);
 vec3 dirt=mix(vec3(.43,.38,.27),vec3(.48,.43,.30),step(.55,a));
 dirt=mix(dirt,vec3(.34,.34,.23),step(.97,a));
 ALBEDO=mix(grass,dirt,clearing*.88);
 ROUGHNESS=1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func cliff_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
varying vec3 w;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float stripe=step(.12,fract(w.y*2.4));
 float noise=hash(floor(w.xz*10.0)+floor(w.y*20.0));
 vec3 c=mix(vec3(.28,.25,.27),vec3(.48,.43,.36),noise*.55+stripe*.35);
 float moss=step(.83,hash(floor(w.xz*3.0)))*smoothstep(-1.2,.05,w.y);
 ALBEDO=mix(c,vec3(.20,.35,.20),moss*.7);ROUGHNESS=1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func prop(frame: int, pos: Vector3, height: float, flip: bool = false) -> Sprite3D:
	var sprite := Sprite3D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SCENERY
	var full := Vector2(SCENERY.get_width(), SCENERY.get_height())
	var row_top := 0.0 if frame < 4 else 0.64
	var row_height := 0.64 if frame < 4 else 0.36
	atlas.region = Rect2(Vector2((frame % 4) * full.x / 4, row_top * full.y), Vector2(full.x / 4, row_height * full.y))
	sprite.texture = atlas
	sprite.pixel_size = height / atlas.region.size.y
	sprite.position = pos
	sprite.offset = Vector2(0, atlas.region.size.y * 0.455)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.shaded = false
	sprite.flip_h = flip
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

func _ready() -> void:
	var grass := ground_material()
	var cliff := cliff_material()
	var dark_grass := V.material(Color("315c3c"), 0, 1)
	# A layered clearing, raised banks and a stream exist in real 3D space.
	V.box(self, Vector3(19, 2, 12), Vector3(0, -1.05, 0), cliff)
	V.box(self, Vector3(19, 0.08, 12), Vector3(0, -0.015, 0), grass)
	V.box(self, Vector3(25, 3.0, 5), Vector3(0, -0.85, -8.1), cliff)
	V.box(self, Vector3(25, 0.12, 5), Vector3(0, 0.68, -8.1), dark_grass)
	V.box(self, Vector3(31, 4.0, 6), Vector3(0, -0.15, -13.0), cliff)
	V.box(self, Vector3(31, 0.12, 6), Vector3(0, 1.9, -13), dark_grass)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4291
	# Hand-placed foreground corners frame the fighting lane without hiding it.
	for row in range(3):
		for i in range(4):
			var grove := prop(0, Vector3(-18.0 + i * 12.0 + (row%2)*3, 0.72 if row == 0 else 1.98, -7.7-row*4), 7.8+row*.6, i%2==0)
			var atlas := AtlasTexture.new()
			atlas.atlas = SCENERY
			atlas.region = Rect2(0, 0, SCENERY.get_width(), SCENERY.get_height()*.64)
			grove.texture = atlas
			if row == 2:
				grove.modulate = Color("abc5ae")
	for side in [-1.0, 1.0]:
		prop(3, Vector3(side * 8.0, 0.05, -3.0), 5.3, side<0)
		prop(0 if side<0 else 1, Vector3(side * 10.3, 0.05, 1.3), 6.7, side<0)
		prop(5, Vector3(side * 7.9, 0.06, 1.8), 2.7)
		prop(7, Vector3(side * 7.6, 0.06, -3.2), 2.6, side<0)
		prop(4, Vector3(side * 7.2, 0.06, 3.7), 2.4)
		prop(3, Vector3(side * 10.0, 0.05, 5.0), 6.4)
	# Many small flowers are placed along the arena edge, not in the fighting lane.
	for i in range(28):
		var x := rng.randf_range(-8.7, 8.7)
		var z := rng.randf_range(3.8, 5.6) if i%2==0 else rng.randf_range(-5.4, -4.0)
		prop(6 if i%3 else 4, Vector3(x, 0.06, z), rng.randf_range(0.9, 1.7), i%2==0)
	# Stone ring markers and lanterns make the arena boundaries legible.
	var rock := V.material(Color("7f8270"), 0, 1)
	var gold := V.material(Color("edbd70"), 0, 1)
	for i in range(28):
		var angle := TAU*i/28
		var stone := V.box(self, Vector3(0.22, 0.035, 0.12), Vector3(sin(angle)*6.8, 0.055, cos(angle)*3.6), rock)
		stone.rotation.y = angle
	for x in [-6.6, 6.6]:
		V.box(self, Vector3(0.45, 0.14, 0.45), Vector3(x, 0.12, -3.5), rock)
		V.box(self, Vector3(0.18, 0.48, 0.18), Vector3(x, 0.41, -3.5), rock)
		V.box(self, Vector3(0.38, 0.32, 0.38), Vector3(x, 0.76, -3.5), gold)
		V.box(self, Vector3(0.55, 0.12, 0.55), Vector3(x, 1.0, -3.5), rock)
	# Stream and small waterfall to the right of the raised bank.
	var water := V.material(Color("5fb5bc"), 0.1, 0.35)
	V.box(self, Vector3(2.0, 0.05, 5.5), Vector3(9.8, -0.55, -4.1), water)
	for i in range(7):
		var ribbon := V.box(self, Vector3(0.12, 1.5, 0.03), Vector3(9.1+i*.18, 0.05, -5.6), V.material(Color("d0e9d1"), 0, 0.8))
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bad4ba")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0edd0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color("c4d9bb")
	env.fog_density = 0.004
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -25, -8)
	sun.light_color = Color("ffeac2")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35
	add_child(sun)
	# Subtle drifting motes are low-cost geometry and preserve a living scene.
	var mote_mat := V.material(Color("fff1b4"), 0, 1, 0.4)
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(24):
		var mote := V.box(self, Vector3(0.025, 0.025, 0.025), Vector3(rng.randf_range(-9,9),rng.randf_range(0.5,4),rng.randf_range(-6,4)), mote_mat)
		mote.set_meta("home", mote.position)
		leaves.append(mote)

func _process(dt: float) -> void:
	time += dt
	for i in range(leaves.size()):
		var home: Vector3 = leaves[i].get_meta("home")
		leaves[i].position = home + Vector3(sin(time*.3+i)*.4, sin(time*.6+i)*.25, cos(time*.3+i)*.2)
