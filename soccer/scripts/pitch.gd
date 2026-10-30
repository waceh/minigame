extends Node3D
const V = preload("res://scripts/visuals.gd")
const FOREST = preload("res://assets/forest.png")
const HALF_X := 23.0
const HALF_Z := 14.0
const GOAL := 3.0
var white: StandardMaterial3D
func segment(a: Vector3, b: Vector3, thickness: float, mat: Material) -> void:
	var n := V.box(self, Vector3(thickness, thickness, a.distance_to(b)), (a+b)/2, mat)
	if a.distance_to(b) > 0.001:
		n.look_at_from_position((a+b)/2, b, Vector3.FORWARD if absf((b-a).normalized().dot(Vector3.UP))>.95 else Vector3.UP)
func mark(a: Vector2, b: Vector2, width: float = .095) -> void:
	segment(Vector3(a.x,.035,a.y), Vector3(b.x,.035,b.y), width, white)
func rect_mark(x: float, z: float, width: float, depth: float) -> void:
	mark(Vector2(x,z),Vector2(x+width,z));mark(Vector2(x+width,z),Vector2(x+width,z+depth));mark(Vector2(x+width,z+depth),Vector2(x,z+depth));mark(Vector2(x,z+depth),Vector2(x,z))
func grove(pos: Vector3, height: float, flip: bool = false) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas=FOREST;atlas.region=Rect2(0,0,FOREST.get_width(),FOREST.get_height()*.64)
	var sprite:=Sprite3D.new()
	sprite.texture=atlas;sprite.pixel_size=height/atlas.region.size.y;sprite.position=pos
	sprite.offset=Vector2(0,atlas.region.size.y*.455);sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded=false;sprite.flip_h=flip;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
func _ready() -> void:
	white=V.material(Color("e3ead2"),0,1)
	var grass:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="""shader_type spatial;varying vec3 w;float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}void vertex(){w=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}void fragment(){float stripe=step(.5,fract((w.x+23.)/9.2));float n=hash(floor(w.xz*20.));ALBEDO=mix(vec3(.115,.29,.18),vec3(.15,.35,.205),stripe)+vec3(.017,.02,.007)*n;ROUGHNESS=1.;}"""
	grass.shader=shader
	V.box(self,Vector3(54,1.5,37),Vector3(0,-.8,0),V.material(Color("665c45"),0,1))
	V.box(self,Vector3(53,.08,36),Vector3(0,-.02,0),grass)
	rect_mark(-23,-14,46,28)
	mark(Vector2(0,-14),Vector2(0,14))
	for i in range(96):
		var a:=TAU*i/96;var b:=TAU*(i+1)/96
		mark(Vector2(cos(a),sin(a))*3.6,Vector2(cos(b),sin(b))*3.6,.075)
	V.cylinder(self,.16,.16,.03,Vector3(0,.04,0),white)
	for side in [-1.0,1.0]:
		rect_mark(side*23,-7,-side*7,14)
		rect_mark(side*23,-4,-side*2.6,8)
		V.cylinder(self,.13,.13,.03,Vector3(side*18,.04,0),white)
		for z in [-3.0,3.0]:
			segment(Vector3(side*23,.05,z),Vector3(side*23,2.3,z),.13,white)
			segment(Vector3(side*23,2.3,z),Vector3(side*24.5,2.3,z),.08,white)
			segment(Vector3(side*24.5,.05,z),Vector3(side*24.5,2.3,z),.07,white)
		segment(Vector3(side*23,2.3,-3),Vector3(side*23,2.3,3),.13,white)
		var net:=V.material(Color("b7cabd"),0,1)
		for j in range(13):
			var z:float=-3+j*.5
			segment(Vector3(side*24.5,.05,z),Vector3(side*24.5,2.3,z),.025,net)
			segment(Vector3(side*23,2.3,z),Vector3(side*24.5,2.3,z),.025,net)
		for j in range(6):
			var y:float=.05+j*.45
			segment(Vector3(side*24.5,y,-3),Vector3(side*24.5,y,3),.025,net)
			for z in [-3.0,3.0]:
				segment(Vector3(side*23,y,z),Vector3(side*24.5,y,z),.025,net)
		for z in [-14.0,14.0]:
			segment(Vector3(side*23,0,z),Vector3(side*23,1.1,z),.05,white)
			V.box(self,Vector3(.4,.28,.025),Vector3(side*23+.2,.95,z),V.material(Color("e6b95c")))
	# Detailed pixel groves surround the stadium; layered stands remain real 3D.
	for row in range(2):
		for i in range(6):
			grove(Vector3(-34+i*13,1.2,-18.5-row*5),5.2+row*1.4,i%2==0)
	var wood:=V.material(Color("514c3d"),0,1)
	var seat:=V.material(Color("748067"),0,1)
	for z in [-18.0,18.0]:
		for row in range(3):
			V.box(self,Vector3(45,.5,1.0),Vector3(0,.2+row*.45,z+signf(z)*row*.8),wood)
			V.box(self,Vector3(45,.1,.75),Vector3(0,.5+row*.45,z+signf(z)*row*.8),seat)
	# Tiny pixel spectators add color without obscuring the pitch.
	var rng:=RandomNumberGenerator.new();rng.seed=1122
	var crowd_colors: Array[StandardMaterial3D]=[]
	for color in ["65c7ab","f18a70","dfcc88","83a5d0","a998bc"]:
		crowd_colors.append(V.material(Color(color),0,1))
	for i in range(120):
		var x:=rng.randf_range(-21,21);var z:float=(-18.5 if i%2==0 else 18.5)+(-.8 if i%2==0 else .8)*(i%3)
		var y:float=.9+(i%3)*.45
		V.box(self,Vector3(.25,.38,.2),Vector3(x,y,z),crowd_colors[i%5])
		V.box(self,Vector3(.21,.21,.21),Vector3(x,y+.29,z),V.material(Color("d9ad80"),0,1))
	var admat:=V.material(Color("253e35"),0,1)
	for x in [-15.0,0.0,15.0]:
		V.box(self,Vector3(11,.65,.12),Vector3(x,.35,-15.8),admat)
		var signboard:=Label3D.new();signboard.text="FOREST  /  FOOTBALL";signboard.font_size=44;signboard.pixel_size=.009;signboard.position=Vector3(x,.42,-15.71);signboard.modulate=Color("f0dfad");add_child(signboard)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("b8cbb0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e3ead3");env.ambient_light_energy=.55
	env.fog_enabled=true;env.fog_light_color=Color("c3d7b4");env.fog_density=.0015
	environment.environment=env;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-65,-30,0);sun.light_energy=.65;sun.light_color=Color("fff0cf");sun.shadow_enabled=true;add_child(sun)
