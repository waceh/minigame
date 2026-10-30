extends Node3D
const V = preload("res://scripts/visuals.gd")
var team := 0
var shirt_number := 1
var goalkeeper := false
var home := Vector3.ZERO
var heading := Vector3.RIGHT
var velocity := Vector3.ZERO
var stamina := 100.0
var cooldown := 0.0
var stun := 0.0
var kick_time := 0.0
var possession_time := 0.0
var skill_time := 0.0
var skill_cooldown := 0.0
var skill_direction := Vector3.ZERO
var skill_kind := ""
var support_time := 0.0
var support_target := Vector3.ZERO
var celebrate_time := 0.0
var dive_time := 0.0
var dive_side := 1.0
var anim := 0.0
var gait := 0.0
var rig: Node3D
var body: Node3D
var limbs: Dictionary = {}
var extremities: Dictionary = {}
var marker: MeshInstance3D
var arrow: MeshInstance3D
var shirt_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D
var shorts_mat: StandardMaterial3D
var sock_mat: StandardMaterial3D
var boot_mat: StandardMaterial3D
var white_mat: StandardMaterial3D

func ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := V.sphere(parent, 1, pos, mat)
	mesh.scale = size
	return mesh

# Rounded cross-sections make shoulders, cloth and limbs continuous 3D surfaces.
func profile(parent: Node3D, sections: Array, mat: Material, segments: int = 12) -> MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
	var ascending:bool=sections[-1].y>sections[0].y
	for row in range(sections.size()-1):
		var a:Vector3=sections[row];var b:Vector3=sections[row+1]
		for j in range(segments):
			var u:=TAU*j/segments;var v:=TAU*(j+1)/segments
			var pts=[Vector3(cos(u)*a.x,a.y,sin(u)*a.z),Vector3(cos(v)*a.x,a.y,sin(v)*a.z),Vector3(cos(u)*b.x,b.y,sin(u)*b.z),Vector3(cos(v)*b.x,b.y,sin(v)*b.z)]
			for k in ([0,1,2,1,3,2] if ascending else [0,2,1,1,2,3]):st.add_vertex(pts[k])
	for end in [0,sections.size()-1]:
		var section:Vector3=sections[end]
		for j in range(segments):
			var u:=TAU*j/segments;var v:=TAU*(j+1)/segments
			var points=[Vector3(0,section.y,0),Vector3(cos(u)*section.x,section.y,sin(u)*section.z),Vector3(cos(v)*section.x,section.y,sin(v)*section.z)]
			for k in ([0,2,1] if (end==0)==ascending else [0,1,2]):st.add_vertex(points[k])
	st.index();st.generate_normals();return V.mesh(parent,st.commit(),Vector3.ZERO,mat)

# Bake the static colored shapes of each animated body part into a single draw.
func bake(root: Node3D) -> void:
	var meshes:Array[MeshInstance3D]=[]
	for child in root.get_children():
		if child is MeshInstance3D:meshes.append(child)
	if meshes.is_empty():return
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for node in meshes:
		var arrays:=node.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var color:Color=node.material_override.albedo_color.srgb_to_linear()
		var count:=indices.size() if not indices.is_empty() else vertices.size()
		for i in range(count):
			var k:=indices[i] if not indices.is_empty() else i
			st.set_color(color)
			if k<normals.size():st.set_normal((node.transform.basis.inverse().transposed()*normals[k]).normalized())
			st.add_vertex(node.transform*vertices[k])
		root.remove_child(node);node.free()
	st.index()
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=false;mat.roughness=.82
	V.mesh(root,st.commit(),Vector3.ZERO,mat)

func setup(side: int, number: int, spawn: Vector3) -> void:
	team=side;shirt_number=number;goalkeeper=number==1;home=spawn;position=spawn
	heading=Vector3.RIGHT if team==0 else Vector3.LEFT
	var shirt:=Color("147ed0") if side==0 else Color("e54b48")
	if goalkeeper:shirt=Color("f0b72e") if side==0 else Color("6bb66b")
	shirt_mat=V.material(shirt,0,.88)
	shorts_mat=V.material(Color("e4e9ef") if side==0 else Color("17243b"),0,.94)
	sock_mat=V.material(shirt.lightened(.1),0,.9)
	var skins=[Color("dca17d"),Color("b77c55"),Color("e6b78e"),Color("88583e"),Color("c68d65")]
	skin_mat=V.material(skins[(number+side*2)%skins.size()],0,.9)
	white_mat=V.material(Color("f1f2ee"),0,.7)
	boot_mat=V.material(Color("e8db60") if number%3==0 else Color("f17843") if number%3==1 else Color("172532"),0,.52)
	rig=Node3D.new();add_child(rig)
	body=Node3D.new();rig.add_child(body)
	profile(body,[Vector3(.15,.96,.105),Vector3(.165,1.08,.11),Vector3(.19,1.28,.125),Vector3(.225,1.43,.115),Vector3(.19,1.50,.1),Vector3(.085,1.55,.07)],shirt_mat,16)
	profile(body,[Vector3(.15,.90,.105),Vector3(.145,.97,.10)],shorts_mat)
	V.cylinder(body,.06,.075,.12,Vector3(0,1.57,0),skin_mat)
	ellipsoid(body,Vector3(.112,.148,.11),Vector3(0,1.735,-.005),skin_mat)
	var hair:=V.material(Color("30241e") if number%3 else Color("151c21"),0,.96)
	ellipsoid(body,Vector3(.116,.074,.113),Vector3(0,1.835,.006),hair)
	if number%4==0:ellipsoid(body,Vector3(.112,.09,.09),Vector3(0,1.80,.04),hair)
	for x in [-.048,.048]:
		ellipsoid(body,Vector3(.014,.009,.008),Vector3(x,1.755,-.108),V.material(Color("272d2c")))
		ellipsoid(body,Vector3(.017,.031,.021),Vector3(signf(x)*.115,1.73,0),skin_mat)
	ellipsoid(body,Vector3(.019,.03,.023),Vector3(0,1.722,-.115),skin_mat)
	V.box(body,Vector3(.042,.008,.008),Vector3(0,1.678,-.105),V.material(Color("7a4b3e")))
	var collar:=V.ring(body,.072,.012,Vector3(0,1.55,0),white_mat)
	collar.scale.z=.8
	V.box(body,Vector3(.045,.055,.015),Vector3(-.11,1.41,-.127),white_mat)
	for z in [-.13,.125]:
		var label:=Label3D.new();label.text="FC" if z<0 else str(number);label.font_size=32 if z<0 else 64;label.pixel_size=.0025 if z<0 else .0032;label.position=Vector3(.085 if z<0 else 0,1.4 if z<0 else 1.25,z);label.modulate=Color.WHITE;label.outline_size=0;label.no_depth_test=false
		if z<0:label.rotation.y=PI
		body.add_child(label)
	bake(body)
	for side_name in ["l","r"]:
		for part in ["thigh","shin","upper_arm","forearm"]:
			var limb:=Node3D.new();rig.add_child(limb);limbs[side_name+part]=limb
			match part:
				"thigh":
					profile(limb,[Vector3(.095,0,.105),Vector3(.105,-.38,.10),Vector3(.075,-1,.075)],skin_mat)
					profile(limb,[Vector3(.125,.035,.12),Vector3(.128,-.52,.125)],shorts_mat)
					V.box(limb,Vector3(.022,.47,.013),Vector3(-.12 if side_name=="l" else .12,-.22,-.06),shirt_mat)
				"shin":
					profile(limb,[Vector3(.07,0,.07),Vector3(.078,-.20,.073)],skin_mat)
					profile(limb,[Vector3(.087,-.18,.084),Vector3(.073,-.6,.074),Vector3(.048,-1.05,.054)],sock_mat)
					profile(limb,[Vector3(.092,-.18,.09),Vector3(.09,-.29,.088)],white_mat)
				"upper_arm":
					profile(limb,[Vector3(.075,0,.08),Vector3(.08,-.3,.077),Vector3(.053,-1,.057)],skin_mat)
					profile(limb,[Vector3(.098,.06,.095),Vector3(.09,-.42,.085)],shirt_mat)
					profile(limb,[Vector3(.102,-.36,.098),Vector3(.099,-.43,.096)],white_mat)
				"forearm":
					profile(limb,[Vector3(.056,0,.057),Vector3(.057,-.4,.053),Vector3(.035,-1,.04)],skin_mat)
			bake(limb)
		for part in ["foot","hand"]:
			var node:=Node3D.new();rig.add_child(node);extremities[side_name+part]=node
			if part=="foot":
				ellipsoid(node,Vector3(.08,.064,.155),Vector3(0,.015,-.055),boot_mat)
				V.box(node,Vector3(.13,.025,.25),Vector3(0,-.027,-.055),V.material(Color("1c282c"),0,.9))
				for z in [-.13,-.09,-.05]:V.box(node,Vector3(.083,.012,.009),Vector3(0,.07,z),white_mat)
			else:
				ellipsoid(node,Vector3(.039,.065,.035),Vector3(0,-.025,0),white_mat if goalkeeper else skin_mat)
				if goalkeeper:ellipsoid(node,Vector3(.055,.08,.045),Vector3(0,-.025,0),white_mat)
			bake(node)
	var marker_mat:=V.material(Color("91e7fe"),0,.9,.3)
	marker_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker=V.ring(self,.48,.025,Vector3(0,.04,0),marker_mat);marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var triangle:=PrismMesh.new();triangle.size=Vector3(.18,.19,.04)
	arrow=V.mesh(self,triangle,Vector3(0,2.08,0),marker_mat);arrow.rotation.z=PI;arrow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadowmat:=V.material(Color(.01,.02,.025,.19));shadowmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shadowmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow:=V.cylinder(self,.3,.3,.002,Vector3(0,.028,0),shadowmat,20);shadow.scale.z=.6;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animate(0,false)

func set_limb(key: String, a: Vector3, b: Vector3) -> void:
	var node:Node3D=limbs[key];var y:Vector3=(a-b).normalized()
	var guide:=Vector3.FORWARD if absf(y.dot(Vector3.FORWARD))<.95 else Vector3.RIGHT
	var x:=y.cross(guide).normalized()
	node.transform=Transform3D(Basis(x,y,x.cross(y).normalized()),a)
	node.scale.y=a.distance_to(b)

func animate(dt: float, selected: bool) -> void:
	skill_time=maxf(0,skill_time-dt);skill_cooldown=maxf(0,skill_cooldown-dt);support_time=maxf(0,support_time-dt)
	dive_time=maxf(0,dive_time-dt);celebrate_time=maxf(0,celebrate_time-dt)
	anim+=dt;cooldown=maxf(0,cooldown-dt);stun=maxf(0,stun-dt);kick_time=maxf(0,kick_time-dt)
	var speed:=velocity.length();var running:=speed>.3
	gait+=speed*dt*3.5
	var phase:=sin(gait);var step_size:=clampf(speed*.065,0,.44)
	var bob:=absf(cos(gait))*.025 if running else 0.0
	var wanted:=atan2(-heading.x,-heading.z)
	rig.rotation.y=lerp_angle(rig.rotation.y,wanted,minf(dt*14,1)) if dt>0 else wanted
	rig.rotation.x=lerpf(rig.rotation.x,-.09 if running else 0,minf(dt*12,1))
	rig.rotation.z=sin(anim*30)*.09 if stun>0 else sin(anim*32)*.18 if skill_time>0 else 0
	rig.position.y=0
	body.position.y=bob
	var kick:=sin(clampf(1-kick_time/.25,0,1)*PI) if kick_time>0 else 0.0
	for side in ["l","r"]:
		var sign_side:float=-1 if side=="l" else 1
		var stride:float=phase*sign_side
		var lift:=maxf(0,stride)*.14 if running else 0.0
		var hip:=Vector3(sign_side*.125,.94+bob,0)
		var knee:=Vector3(sign_side*.13,.52+lift*.65,-stride*step_size*.5-.035)
		var foot:=Vector3(sign_side*.14,.065+lift,-stride*step_size)
		if side=="r" and kick>0:
			knee=knee.lerp(Vector3(.13,.70,-.28),kick)
			foot=foot.lerp(Vector3(.13,.50,-.72),kick)
		set_limb(side+"thigh",hip,knee);set_limb(side+"shin",knee,foot)
		extremities[side+"foot"].position=foot
		extremities[side+"foot"].rotation.x=stride*.16 if running else 0
		var shoulder:=Vector3(sign_side*.245,1.45+bob,0)
		var elbow:=Vector3(sign_side*.28,1.16+bob,stride*step_size*.5)
		var hand:=Vector3(sign_side*.26,1.04+bob,-.03)
		if running:
			hand=Vector3(sign_side*.27,1.22+bob,stride*step_size*.9-.09)
		if goalkeeper:
			elbow.z=-.09;hand=Vector3(sign_side*.30,1.14,-.18)
		if celebrate_time>0:
			elbow=Vector3(sign_side*.34,1.68,-.06);hand=Vector3(sign_side*.4,1.95,-.12)
		set_limb(side+"upper_arm",shoulder,elbow);set_limb(side+"forearm",elbow,hand)
		extremities[side+"hand"].position=hand
	if dive_time>0:
		rig.rotation.z=dive_side*sin((1-dive_time/.5)*PI)*1.1
		rig.position.y=.1
	marker.visible=selected;arrow.visible=selected
	if selected:
		var cam:=get_viewport().get_camera_3d()
		if cam:arrow.rotation.y=cam.rotation.y
