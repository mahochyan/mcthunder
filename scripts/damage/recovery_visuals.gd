class_name RecoveryVisuals
extends Node3D
## Read-only bounded fire, blast and wreck presentation. Actual detached armor
## moves only through WreckTurretMotion, owned by Actor's committed lifecycle.
const BURN_SECONDS := 45.0
const SMOKE_SECONDS := 60.0
var actor: VehicleActor
var _flames: Array[MeshInstance3D] = []
var _original: Array[Dictionary] = []
var _was_destroyed := false
var _generation := -1
var _time := 0.0
var death_age := 0.0
var blast_count := 0
var _burning_wreck := false
var _detonated := false
var _smoke: MultiMeshInstance3D
var _blast: MeshInstance3D
var _light: OmniLight3D
var _smoke_age := 0.0
var _burst_lobes: Array[MeshInstance3D] = []

func setup(vehicle: VehicleActor) -> void:
	actor=vehicle; process_mode=Node.PROCESS_MODE_PAUSABLE; _generation=vehicle.state.generation
	refresh_materials()
	var flame_mesh:=CylinderMesh.new(); flame_mesh.radial_segments=7; flame_mesh.rings=1
	flame_mesh.top_radius=0.04; flame_mesh.bottom_radius=0.22; flame_mesh.height=0.8
	for i in 7:
		var flame:=MeshInstance3D.new(); flame.mesh=flame_mesh; flame.layers=vehicle.tank.visual_layer
		flame.material_override=_glow("fire" if i%2==0 else "ember")
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; flame.visible=false
		add_child(flame); _flames.append(flame)
	var smoke_mesh:=SphereMesh.new(); smoke_mesh.radial_segments=7; smoke_mesh.rings=3; smoke_mesh.radius=0.5; smoke_mesh.height=1.0
	_smoke=MultiMeshInstance3D.new(); _smoke.name="WreckSmoke"; _smoke.layers=vehicle.tank.visual_layer
	_smoke.multimesh=MultiMesh.new(); _smoke.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	_smoke.multimesh.use_colors=true
	_smoke.multimesh.mesh=smoke_mesh; _smoke.multimesh.instance_count=10
	var smoke_material:=ArtPalette.material("smoke",true).duplicate() as StandardMaterial3D
	smoke_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke.material_override=smoke_material; _smoke.visible=false
	_smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(_smoke)
	_blast=MeshInstance3D.new(); _blast.name="AmmunitionBlast"; _blast.mesh=smoke_mesh
	_blast.material_override=_glow("ember"); _blast.layers=vehicle.tank.visual_layer
	_blast.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _blast.visible=false; add_child(_blast)
	for i in 5:
		var lobe:=MeshInstance3D.new(); lobe.mesh=smoke_mesh; lobe.material_override=_glow("fire" if i%2==0 else "ember")
		lobe.layers=vehicle.tank.visual_layer; lobe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; lobe.visible=false
		add_child(lobe); _burst_lobes.append(lobe)
	_light=OmniLight3D.new(); _light.omni_range=9; _light.light_color=ArtPalette.color("fire"); _light.light_energy=0; _light.shadow_enabled=false
	add_child(_light)

func _glow(key: String) -> StandardMaterial3D:
	var material:=ArtPalette.material(key).duplicate() as StandardMaterial3D
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func refresh_materials() -> void:
	_original.clear()
	for mesh in actor.tank.find_children("*","GeometryInstance3D",true,false):
		if not mesh.is_queued_for_deletion(): _original.append({"mesh":mesh,"material":mesh.material_override})

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or get_tree().paused: return
	_time+=delta
	if actor.state.generation!=_generation:
		_generation=actor.state.generation; _was_destroyed=false; _burning_wreck=false; _detonated=false; death_age=0; blast_count=0; _smoke_age=0
		_set_charred(false)
	if actor.state.destroyed and not _was_destroyed:
		_was_destroyed=true; death_age=0
		var cause:=str(actor.state.death_record.get("cause",""))
		_detonated=cause=="ammo_detonation"; _burning_wreck=_detonated or cause=="fire_crew_out"
		if _detonated: blast_count+=1
		_set_charred(true)
	if _was_destroyed: death_age+=delta
	if AccessibilitySettings.fx_level==0:
		for flame in _flames: flame.visible=false
		for lobe in _burst_lobes: lobe.visible=false
		_smoke.visible=false; _blast.visible=false; _light.light_energy=0
		return
	if actor.state.fires.is_empty() and (not _burning_wreck or death_age>=SMOKE_SECONDS):
		for flame in _flames: flame.visible=false
		for lobe in _burst_lobes: lobe.visible=false
		_smoke.visible=false; _blast.visible=false; _light.light_energy=0; _smoke_age=0
		return
	var fire_origin:=_fire_origin()
	var fire_active:=not actor.state.fires.is_empty() if not actor.state.destroyed else _burning_wreck and death_age<BURN_SECONDS
	for i in _flames.size():
		var flame:=_flames[i]; flame.visible=fire_active
		var cycle:=fmod(_time*1.7+i*0.37,1.0)
		flame.global_position=fire_origin+Vector3(sin(i*2.4)*0.5,0.25+cycle*1.1,cos(i*2.4)*0.5)
		flame.scale=Vector3(0.65,0.6+sin(_time*8+i)*0.18,0.65)*(1.5 if actor.state.destroyed else 1.0)
	_smoke.visible=not actor.state.fires.is_empty() or _burning_wreck and death_age<SMOKE_SECONDS
	_smoke_age+=delta
	_smoke.global_position=fire_origin
	for i in 10:
		var age:=fposmod(_smoke_age-i*0.32,3.2)
		var scale: float=maxf(0.001,(0.45+age*0.4)*minf(1.0,(3.2-age)*2)) if _smoke_age>=i*0.32 else 0.001
		var p:=Vector3(sin(i*1.7)*0.25+age*0.25,0.5+age*1.2,cos(i*1.7)*0.3)
		_smoke.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*scale),p))
		_smoke.multimesh.set_instance_color(i,ArtPalette.color("smoke").lerp(Color("777970"),age/4.0))
	_blast.visible=_detonated and death_age<0.65
	_blast.global_position=actor.tank.global_position+Vector3.UP*1.35
	_blast.scale=Vector3.ONE*maxf(0.01,sin(clampf(death_age/0.65,0,1)*PI)*5.0)
	for i in _burst_lobes.size():
		var lobe:=_burst_lobes[i]; lobe.visible=_blast.visible
		lobe.global_position=_blast.global_position+Vector3(sin(i*2.4),0.4+cos(i*1.3)*0.25,cos(i*2.4))*sin(clampf(death_age/0.65,0,1)*PI)*1.7
		lobe.scale=_blast.scale*(0.45+i*0.03)
	_light.global_position=_blast.global_position
	_light.light_energy=2.0*maxf(0,1.0-death_age/0.3) if _detonated else 0.0

func _fire_origin() -> Vector3:
	if not actor.state.destroyed and not actor.state.fires.is_empty() and actor.state._damage_layout!=null:
		var id:=str(actor.state.fires.keys()[0])
		for module in actor.state._damage_layout.modules:
			if module.id==id: return DamageTrainingLayout.part_node(actor,module.part_id).to_global(module.local_box_transform.origin)+Vector3.UP*0.55
	return actor.tank.global_position+Vector3.UP*1.5

func _set_charred(value: bool) -> void:
	for row in _original:
		# Armor is a thin shell, including the open M36 turret. Preserve visibility
		# from both sides when replacing the original two-sided atlas material.
		if is_instance_valid(row.mesh): row.mesh.material_override=ArtPalette.material("charcoal",false,true) if value else row.material
