extends Node3D
const V = preload("res://scripts/visuals.gd")
const HALF_X := 52.5
const HALF_Z := 34.0
const GOAL := 3.66
var white: StandardMaterial3D
func segment(a: Vector3,b: Vector3,thickness: float,mat: Material) -> void:
	var n:=V.box(self,Vector3(thickness,thickness,a.distance_to(b)),(a+b)/2,mat)
	if a.distance_to(b)>.001:n.look_at_from_position((a+b)/2,b,Vector3.FORWARD if absf((b-a).normalized().dot(Vector3.UP))>.95 else Vector3.UP)
func mark(a: Vector2,b: Vector2,width: float=.10) -> void:
	segment(Vector3(a.x,.024,a.y),Vector3(b.x,.024,b.y),width,white)
func rect_mark(x: float,z: float,width: float,depth: float) -> void:
	mark(Vector2(x,z),Vector2(x+width,z));mark(Vector2(x+width,z),Vector2(x+width,z+depth));mark(Vector2(x+width,z+depth),Vector2(x,z+depth));mark(Vector2(x,z+depth),Vector2(x,z))
func pipe(a: Vector3,b: Vector3,radius: float,mat: Material) -> void:
	var n:=V.cylinder(self,radius,radius,a.distance_to(b),(a+b)/2,mat,12)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
func _ready() -> void:
	white=V.material(Color("e8e9df"),0,.92)
	var grass:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="""
shader_type spatial;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float stripe=step(.5,fract((world.x+52.5)/10.5));
 float grain=hash(floor(world.xz*180.));
 float patch=hash(floor(world.xz*1.5));
 vec3 c=mix(vec3(.045,.19,.067),vec3(.064,.245,.09),stripe);
 ALBEDO=c*(.94+grain*.07+patch*.035);
 ROUGHNESS=.96;SPECULAR=.08;
}
"""
	grass.shader=shader
	V.box(self,Vector3(160,.4,115),Vector3(0,-.3,0),V.material(Color("26303b"),0,1))
	V.box(self,Vector3(120,.08,82),Vector3(0,-.06,0),grass)
	rect_mark(-HALF_X,-HALF_Z,HALF_X*2,HALF_Z*2)
	mark(Vector2(0,-HALF_Z),Vector2(0,HALF_Z))
	for i in range(128):
		var a:=TAU*i/128;var b:=TAU*(i+1)/128
		mark(Vector2(cos(a),sin(a))*9.15,Vector2(cos(b),sin(b))*9.15,.08)
	V.cylinder(self,.12,.12,.012,Vector3(0,.028,0),white)
	for side in [-1.0,1.0]:
		rect_mark(side*HALF_X,-20.16,-side*16.5,40.32)
		rect_mark(side*HALF_X,-9.16,-side*5.5,18.32)
		V.cylinder(self,.12,.12,.012,Vector3(side*(HALF_X-11),.028,0),white)
		for i in range(40):
			var a:float=-.92+i*1.84/40;var b:float=-.92+(i+1)*1.84/40
			mark(Vector2(side*(HALF_X-11-cos(a)*9.15),sin(a)*9.15),Vector2(side*(HALF_X-11-cos(b)*9.15),sin(b)*9.15),.08)
		for z in [-GOAL,GOAL]:
			pipe(Vector3(side*HALF_X,.03,z),Vector3(side*HALF_X,2.44,z),.06,white)
			pipe(Vector3(side*HALF_X,2.44,z),Vector3(side*(HALF_X+2),2.3,z),.035,white)
			pipe(Vector3(side*(HALF_X+2),.02,z),Vector3(side*(HALF_X+2),2.3,z),.035,white)
		pipe(Vector3(side*HALF_X,2.44,-GOAL),Vector3(side*HALF_X,2.44,GOAL),.06,white)
		var net:=ImmediateMesh.new();var net_mat:=V.material(Color(.84,.88,.90,.47),0,1)
		net_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;net_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		net.surface_begin(Mesh.PRIMITIVE_LINES,net_mat)
		for j in range(31):
			var z:float=-GOAL+j*GOAL*2/30
			net.surface_add_vertex(Vector3(side*(HALF_X+2),.02,z));net.surface_add_vertex(Vector3(side*(HALF_X+2),2.3,z))
			net.surface_add_vertex(Vector3(side*HALF_X,2.44,z));net.surface_add_vertex(Vector3(side*(HALF_X+2),2.3,z))
		for j in range(11):
			var y:float=.03+j*.23
			net.surface_add_vertex(Vector3(side*(HALF_X+2),y,-GOAL));net.surface_add_vertex(Vector3(side*(HALF_X+2),y,GOAL))
			for z in [-GOAL,GOAL]:
				net.surface_add_vertex(Vector3(side*HALF_X,y,z));net.surface_add_vertex(Vector3(side*(HALF_X+2),y,z))
		net.surface_end();var net_node:=V.mesh(self,net,Vector3.ZERO,null);net_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for z in [-HALF_Z,HALF_Z]:
			pipe(Vector3(side*HALF_X,0,z),Vector3(side*HALF_X,1.6,z),.02,white)
			V.box(self,Vector3(.36,.26,.015),Vector3(side*HALF_X+.18,1.45,z),V.material(Color("f0b844"),0,1))
			for j in range(16):
				var a:float=j*PI*.5/16;var b:float=(j+1)*PI*.5/16
				mark(Vector2(side*(HALF_X-cos(a)),signf(z)*(HALF_Z-sin(a))),Vector2(side*(HALF_X-cos(b)),signf(z)*(HALF_Z-sin(b))),.08)
	build_stadium()
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("496d94");sky_mat.sky_horizon_color=Color("b6c9da");sky_mat.ground_bottom_color=Color("222e3a");sky_mat.ground_horizon_color=Color("b6c9da");sky.sky_material=sky_mat
	env.background_mode=Environment.BG_SKY;env.sky=sky;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b9c9df");env.ambient_light_energy=.50
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true;env.fog_light_color=Color("b1bfce");env.fog_density=.0006
	environment.environment=env;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-53,-36,-4);sun.light_energy=1.25;sun.light_color=Color("fff3df");sun.shadow_enabled=true;sun.directional_shadow_max_distance=100;sun.shadow_bias=.035;add_child(sun)

func build_stadium() -> void:
	var concrete:=V.material(Color("4c5867"),0,.95)
	var dark:=V.material(Color("172433"),.2,.65)
	var roof:=V.material(Color("a3acb6"),.45,.55)
	var seat:=V.material(Color("3f577a"),.1,.85)
	var aisle:=V.material(Color("8c9295"),0,.95)
	var crowd:Array[Vector3]=[]
	for sign_side in [-1.0,1.0]:
		for row in range(12):
			var y:=.5+row*.78;var z:float=sign_side*(44+row*1.25)
			V.box(self,Vector3(143,.74,1.3),Vector3(0,y-.35,z),concrete)
			V.box(self,Vector3(143,.22,.65),Vector3(0,y+.15,z),seat)
			for col in range(180):
				var x:float=-70+col*.78
				if col%30 in [0,1,2]:continue
				crowd.append(Vector3(x,y+.6,z))
		for row in range(10):
			var y:=.5+row*.78;var x:float=sign_side*(61+row*1.25)
			V.box(self,Vector3(1.3,.74,86),Vector3(x,y-.35,0),concrete)
			V.box(self,Vector3(.65,.22,86),Vector3(x,y+.15,0),seat)
			for col in range(110):
				if col%27 in [0,1,2]:continue
				crowd.append(Vector3(x,y+.6,-42+col*.78))
		V.box(self,Vector3(147,.35,11),Vector3(0,15.5,sign_side*59),roof)
		V.box(self,Vector3(9,.35,88),Vector3(sign_side*75,14,0),roof)
		for x in range(-66,67,22):
			pipe(Vector3(x,1,sign_side*59),Vector3(x,15.4,sign_side*59),.13,dark)
			pipe(Vector3(x,15.1,sign_side*59),Vector3(x,13.5,sign_side*52),.09,roof)
		for z in range(-36,37,18):pipe(Vector3(sign_side*75,1,z),Vector3(sign_side*75,13.8,z),.13,dark)
		# Perimeter LED boards, separated from the active touchline.
		V.box(self,Vector3(112,.8,.18),Vector3(0,.42,sign_side*37.5),dark)
		V.box(self,Vector3(.18,.8,73),Vector3(sign_side*57.5,.42,0),dark)
		for i in range(8):
			var label:=Label3D.new();label.text=["CLUB FOOTBALL","PLAY THE GAME","11 v 11","MATCHDAY"][i%4];label.font_size=64;label.pixel_size=.014;label.position=Vector3(-48+i*14,.50,sign_side*37.38);label.modulate=Color("b8e6fd") if i%2==0 else Color("dcf879");label.outline_size=0
			if sign_side>0:label.rotation.y=PI
			add_child(label)
	# Two instanced meshes represent thousands of spectators in four stands.
	var rng:=RandomNumberGenerator.new();rng.seed=11023
	var shirts:=MultiMesh.new();shirts.transform_format=MultiMesh.TRANSFORM_3D;shirts.use_colors=true
	var mesh:=BoxMesh.new();mesh.size=Vector3(.36,.48,.24);shirts.mesh=mesh;shirts.instance_count=crowd.size()
	var heads:=MultiMesh.new();heads.transform_format=MultiMesh.TRANSFORM_3D;heads.use_colors=true
	var sphere:=SphereMesh.new();sphere.radius=.13;sphere.height=.28;sphere.radial_segments=8;sphere.rings=4;heads.mesh=sphere;heads.instance_count=crowd.size()
	var palette=[Color("d5d9db"),Color("254d76"),Color("254d76"),Color("bd524c"),Color("363a43"),Color("c3b292"),Color("5f7991")]
	for i in range(crowd.size()):
		var pos:Vector3=crowd[i]+Vector3(0,rng.randf_range(-.06,.07),0)
		shirts.set_instance_transform(i,Transform3D(Basis.IDENTITY,pos));shirts.set_instance_color(i,palette[rng.randi_range(0,palette.size()-1)])
		heads.set_instance_transform(i,Transform3D(Basis.IDENTITY,pos+Vector3(0,.36,0)));heads.set_instance_color(i,Color("cda381").darkened(rng.randf()*.35))
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.roughness=1
	for mm in [shirts,heads]:
		var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	# Technical areas and camera-side benches.
	for x in [-12.0,12.0]:
		V.box(self,Vector3(8,.25,1),Vector3(x,.6,39),dark)
		V.box(self,Vector3(8,.16,2.5),Vector3(x,2.3,39.5),roof)
