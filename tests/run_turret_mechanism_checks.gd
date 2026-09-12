extends SceneTree
## Pure actuator mathematics. Does not claim a driving route or vehicle admission.
var checks := 0
var failures := 0
const DT := 1.0/60.0
const SPEEDS := Vector2(0.5,1.0)
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("[PASS] " if ok else "[FAIL] ")+message)
func _initialize() -> void:
	var profile := FireControlProfile.new()
	check(profile.validate().is_empty() and profile.stabilizer_mode=="none" and profile.provenance=="game_rule","default profile declares unstabilized gameplay response without historical claim")
	var state := TurretMechanismState.new()
	var p := state.step(Vector2.ZERO,Vector2(0.3,1.0),Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	check(state.velocity.x>0 and state.velocity.x<state.velocity.y and state.velocity.y<SPEEDS.y,"axes independently accelerate from rest rather than immediately reaching full rate")
	check(p.x>0 and p.y>0 and p.y<SPEEDS.y*DT,"integrated first movement respects finite mechanism acceleration")
	var monotonic := true
	var bounded := true
	var target := Vector2(0.3,1.0)
	for i in 600:
		var before := p
		var old_velocity := state.velocity
		p=state.step(p,target,Basis.IDENTITY,profile,SPEEDS,0,{},DT)
		monotonic=monotonic and p.x>=before.x-0.0000001 and p.y>=before.y-0.0000001 and p.x<=target.x+0.0000001 and p.y<=target.y+0.0000001
		for axis in 2:
			var change_limit := profile.acceleration()[axis] if absf(state.velocity[axis])>absf(old_velocity[axis]) else profile.braking()[axis]
			bounded=bounded and absf(state.velocity[axis])<=SPEEDS[axis]+0.0000001 and absf(state.velocity[axis]-old_velocity[axis])<=change_limit*DT+0.000001
	check(monotonic and p.distance_to(target)<0.00001,"fixed target converges without overshoot or repeated sign chatter")
	check(bounded,"maximum rates and acceleration/braking limits hold across complete acquisition")
	check(state.velocity.length()<0.00001,"mechanism settles at rest rather than retaining hidden motor velocity")
	state.reset(); p=Vector2.ZERO
	for i in 30: p=state.step(p,Vector2(0,2),Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	var before_reverse := state.velocity.y
	p=state.step(p,Vector2(0,-1),Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	check(before_reverse>0 and state.velocity.y>=0 and state.velocity.y<before_reverse,"opposite aim request first brakes existing yaw motion instead of reversing instantly")
	for i in 600: p=state.step(p,Vector2(0,-1),Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	check(absf(p.y+1)<0.00001 and absf(state.velocity.y)<0.00001,"reversal eventually reacquires and settles at the opposite target")
	state.reset(); p=Vector2(0,PI-0.02)
	var wrapped := Vector2(0,-PI+0.04)
	p=state.step(p,wrapped,Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	check(state.velocity.y>0,"unlimited turret crosses the wrap along the short arc")
	for i in 300: p=state.step(p,wrapped,Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	check(absf(wrapf(p.y-wrapped.y,-PI,PI))<0.00001,"wrap crossing converges without a full rotation")
	state.reset(); p=Vector2(0,deg_to_rad(110))
	p=state.step(p,Vector2(0,deg_to_rad(-110)),Basis.IDENTITY,profile,SPEEDS,0,{"yaw_limited":true},DT)
	check(state.velocity.y<0,"limited turret takes the permitted interior path instead of turning into its end stop")
	state.velocity=Vector2(0,0.5)
	p=state.step(Vector2(0,PI-0.0001),Vector2(0,-2.9),Basis.IDENTITY,profile,SPEEDS,0,{"yaw_limited":true},DT)
	check(p.y>PI,"limited output remains unwrapped so the owning rig clamps the correct physical stop")
	# Isolate the disturbance feed-forward from gunner correction with equal
	# local target/current angles. A rolled hull at a sideways turret requires
	# pitch compensation even though hull Euler pitch is zero.
	var none := FireControlProfile.new()
	var vertical := FireControlProfile.new(); vertical.stabilizer_mode="vertical"
	vertical.pitch_accel_deg_s2=10000; vertical.pitch_brake_deg_s2=10000
	var dual := vertical.duplicate() as FireControlProfile; dual.stabilizer_mode="two_axis"
	dual.yaw_accel_deg_s2=10000; dual.yaw_brake_deg_s2=10000
	var no_state := TurretMechanismState.new()
	var vertical_state := TurretMechanismState.new()
	var dual_state := TurretMechanismState.new()
	var side := Vector2(0,PI*0.5)
	for pair in [[no_state,none],[vertical_state,vertical],[dual_state,dual]]:
		pair[0].step(side,side,Basis.IDENTITY,pair[1],Vector2(3,3),0,{},DT)
	var rolled := Basis(Vector3.BACK,0.02)
	var uncorrected := no_state.step(side,side,rolled,none,Vector2(3,3),0,{},DT)
	var corrected := vertical_state.step(side,side,rolled,vertical,Vector2(3,3),0,{},DT)
	var world_before := TurretMechanismState.direction(side)
	var no_error := world_before.angle_to(rolled*TurretMechanismState.direction(uncorrected))
	var vertical_error := world_before.angle_to(rolled*TurretMechanismState.direction(corrected))
	check(uncorrected==side and no_state.compensation_rate==Vector2.ZERO,"none mode adds no hull disturbance feed-forward")
	check(corrected.x>0 and vertical_state.compensation_rate.x>0 and vertical_error<no_error,"vertical stabilization handles hull-roll coupling when the gun points sideways")
	vertical_state.reset(); dual_state.reset()
	vertical_state.step(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,vertical,Vector2(3,3),0,{},DT)
	dual_state.step(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,dual,Vector2(3,3),0,{},DT)
	var yawed := Basis(Vector3.UP,0.02)
	var vertical_yaw := vertical_state.step(Vector2.ZERO,Vector2.ZERO,yawed,vertical,Vector2(3,3),0,{},DT)
	var dual_yaw := dual_state.step(Vector2.ZERO,Vector2.ZERO,yawed,dual,Vector2(3,3),0,{},DT)
	check(vertical_yaw.y==0 and dual_yaw.y<0,"vertical mode leaves horizontal disturbance while two-axis mode compensates yaw")
	check(Vector3.FORWARD.angle_to(yawed*TurretMechanismState.direction(dual_yaw))<0.02,"dual-axis correction reduces actual world-direction error")
	state.reset(); profile.stabilizer_mode="two_axis"
	state.step(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,profile,SPEEDS,5.1,{},DT)
	check(not state.stabilizer_active and state.stabilizer_reason=="speed_limited","stabilizer disables above configured vehicle speed")
	state.step(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,profile,SPEEDS,4.8,{},DT)
	check(not state.stabilizer_active,"speed hysteresis prevents chatter just below the threshold")
	state.step(Vector2.ZERO,Vector2.ZERO,Basis.IDENTITY,profile,SPEEDS,4.5,{},DT)
	check(state.stabilizer_active and state.stabilized_axes==Vector2i.ONE,"stabilizer restores after crossing the recovery threshold")
	state.step(Vector2.ZERO,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{"stabilizer_available":false},DT)
	check(not state.stabilizer_active and state.velocity.length()>0,"loss of stabilizer leaves working manual mechanism available")
	state.step(Vector2.ZERO,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{"pitch_scale":0.0,"yaw_scale":1.0},DT)
	check(state.velocity.x==0 and state.velocity.y>0 and state.stabilized_axes==Vector2i(0,1),"pitch drive failure disables only its corresponding axis and compensation")
	p=state.step(Vector2.ZERO,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{"turret_speed":0.0},DT)
	check(p==Vector2.ZERO and state.velocity==Vector2.ZERO,"legacy combined drive failure freezes both axes")
	state.reset(); profile.stabilizer_mode="none"; p=Vector2.ZERO
	for i in 20: p=state.step(p,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{},DT)
	var clipped := Vector2(p.x-0.01,p.y)
	state.constrain(clipped)
	check(state.velocity.x==0 and state.velocity.y>0,"physical pitch stop feedback clears only blocked motor velocity")
	var hold_pose := Basis(Vector3.UP,0.3)
	p=state.hold(clipped,hold_pose)
	check(p==clipped and state.velocity==Vector2.ZERO and not state.stabilizer_active,"observation hold stops both mechanism axes without moving them")
	profile.stabilizer_mode="two_axis"
	state.step(clipped,clipped,hold_pose,profile,SPEEDS,0,{},DT)
	check(state.compensation_rate==Vector2.ZERO,"leaving observation does not repay accumulated hull rotation")
	for i in 120:
		state.hold(clipped,Basis.from_euler(Vector3(0.001*i,0.003*i,0.0005*i)))
	var final_hold := Basis.from_euler(Vector3(0.119,0.357,0.0595))
	state.hold(clipped,final_hold)
	p=state.step(clipped,clipped,final_hold,profile,SPEEDS,0,{},DT)
	check(state.compensation_rate==Vector2.ZERO and state.velocity==Vector2.ZERO and p.is_equal_approx(clipped),"extended observation synchronizes hull history without an exit impulse")
	state.step(clipped,clipped,Basis(Vector3.UP,0.00001)*final_hold,profile,SPEEDS,0,{},DT)
	check(state.compensation_rate.length()>0,"real small hull disturbance after observation is still compensated")
	state.step(clipped,Vector2.ONE,hold_pose,profile,SPEEDS,0,{"observation_hold":true},DT)
	check(state.velocity==Vector2.ZERO and state.stabilizer_reason=="observation_hold","hold capability also freezes the normal step entry")
	state.reset()
	check(state.velocity==Vector2.ZERO and state.compensation_rate==Vector2.ZERO and not state._pose_valid,"reset clears rates and pose history")
	profile.response_time_s=0
	check(not profile.validate().is_empty() and state.step(clipped,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{},DT)==clipped,"invalid response profile is rejected without changing pose")
	profile=FireControlProfile.new(); profile.yaw_accel_deg_s2=NAN
	check(not profile.validate().is_empty(),"nonfinite axis acceleration fails profile admission")
	profile=FireControlProfile.new(); profile.speed_hysteresis_mps=profile.speed_limit_mps+1
	check(not profile.validate().is_empty(),"impossible hysteresis fails profile admission")
	profile=FireControlProfile.new()
	check(state.step(clipped,Vector2.ONE,Basis.IDENTITY.scaled(Vector3(2,1,1)),profile,SPEEDS,0,{},DT)==clipped and state.stabilizer_reason=="invalid_input","non-rigid hull transform cannot inject a compensation impulse")
	check(state.step(clipped,Vector2.ONE,Basis.IDENTITY,profile,SPEEDS,0,{},0)==clipped,"zero-duration step cannot advance mechanism")
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("TURRET_MECHANISM_CHECKS_PASS" if failures==0 else "TURRET_MECHANISM_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
