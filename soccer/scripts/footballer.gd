extends Node3D
const V = preload("res://scripts/visuals.gd")
static var frame_baselines: Array[float] = []
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
var anim := 0.0
var sprite: Sprite3D
var marker: MeshInstance3D
func setup(side: int, number: int, spawn: Vector3) -> void:
	team=side;shirt_number=number;goalkeeper=number==1;home=spawn;position=spawn
	heading=Vector3.RIGHT if team==0 else Vector3.LEFT
	sprite=Sprite3D.new();sprite.texture=preload("res://assets/players.png");sprite.hframes=4;sprite.vframes=4
	var cell:=sprite.texture.get_height()/4.0
	sprite.pixel_size=2.0/cell
	if frame_baselines.is_empty():
		var image:=sprite.texture.get_image()
		for frame in range(16):
			var left:=int((frame%4)*cell)
			var top:=int((frame/4)*cell)
			var baseline:=cell*.92
			for y in range(int(cell)-2,0,-1):
				var opaque:=0
				for x in range(8,int(cell)-8,4):
					if image.get_pixel(left+x,top+y).a>.5:opaque+=1
				if opaque>=3:
					baseline=y
					break
			frame_baselines.append(baseline-cell/2)
	sprite.offset=Vector2(0,frame_baselines[side*8])
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.shaded=false
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(sprite)
	marker=V.ring(self,.55,.055,Vector3(0,.045,0),V.material(Color("ffe39c"),0,1,.4));marker.visible=false
	var shadowmat:=V.material(Color(.02,.04,.03,.28));shadowmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shadowmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow:=V.cylinder(self,.4,.4,.002,Vector3(0,.027,0),shadowmat,20);shadow.scale.z=.55;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var number_label:=Label3D.new();number_label.text=str(number);number_label.font_size=28;number_label.pixel_size=.012;number_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;number_label.position=Vector3(0,1.8,0);number_label.modulate=Color("c1f4dc") if team==0 else Color("ffd1ad");add_child(number_label)
func animate(dt: float, selected: bool) -> void:
	skill_time=maxf(0,skill_time-dt);skill_cooldown=maxf(0,skill_cooldown-dt);support_time=maxf(0,support_time-dt)
	anim+=dt;cooldown=maxf(0,cooldown-dt);stun=maxf(0,stun-dt);kick_time=maxf(0,kick_time-dt)
	var run:=velocity.length()>.4
	var base:=0
	if absf(heading.x)>absf(heading.z):
		base=6 if heading.x>0 else 4
	else:
		base=0 if heading.z>0 else 2
	sprite.frame=team*8+base+(1 if (run and int(anim*10)%2==0) or kick_time>0 else 0)
	sprite.offset.y=frame_baselines[sprite.frame]
	sprite.position.y=absf(sin(anim*14))*.04 if run else 0
	sprite.rotation.z=sin(anim*30)*.08 if stun>0 else sin(anim*35)*.15 if skill_time>0 else 0
	sprite.modulate=Color("fff0bd") if skill_time>0 else Color("ffe8a4") if goalkeeper else Color.WHITE
	marker.visible=selected
	marker.rotation.y+=dt
