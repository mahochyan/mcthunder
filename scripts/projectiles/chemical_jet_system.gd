class_name ChemicalJetSystem
extends RefCounted
## Carrier ends at first contact. The terminal ray resolves at that contact pose.
static func emit(st: ProjectileState, trigger: Dictionary, trigger_kind: String, snapshots: Array, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID], commit_damage: Callable, commit_armor: Callable, policy: Callable, live: Callable) -> void:
	var profile := st.chemical_profile
	var direction := st.velocity_world.normalized()
	st.chemical_effect={"rules_version":ChemicalProfile.VERSION,"point_world":st.position_world,"direction":direction,
		"time_s":st.age_s,"trigger_kind":trigger_kind,"trigger_frame":trigger.get("geometry_frame",-1),
		"path":[st.position_world],"contact_indices":[],"damage_indices":[],"queries":0,
		"initial_mm":float(profile.penetration_mm),"remaining_mm":float(profile.penetration_mm),"distance_m":0.0,
		"reason":"world" if trigger_kind=="world" else "contact_limit","complete":false}
	var effect: Dictionary=st.chemical_effect
	if trigger_kind=="world": effect.complete=true; return
	var point := st.position_world
	var budget := float(profile.penetration_mm)
	var remaining := float(profile.range_m)
	var loss := float(profile.path_loss_mm_per_m)
	var eligible := {}; var seen := {}; var surfaces := {}
	for iteration in ChemicalProfile.MAX_CONTACTS:
		if not live.call(st): return
		var event := {}; var status := "miss"; var distance := remaining
		if iteration==0:
			# Keep the proven first contact. Re-querying from its surface must not skip it.
			event=trigger.duplicate(true); status=trigger_kind; distance=0.0
		else:
			var ws := WorldQueryAdapter.query_world_stop(space,point,direction,remaining,exclude)
			if not ws.get("ok",false): effect.reason="unresolved_world"; break
			var query := ShotQueryService.query({"query_id":"chemical_%d_%d"%[st.projectile_id,iteration],"physics_tick":Engine.get_physics_frames(),
				"from_world":point,"to_world":point+direction*remaining,"include_modules":true,"include_crew":true,
				"excluded_instances":[{"entity_id":st.shooter_id,"life_id":st.shooter_life_id}],
				"world_stop":ws.get("contact",{}) if ws.get("hit",false) else {}},snapshots)
			effect.queries+=1
			if not query.get("ok",false) or not query.get("complete",false): effect.reason="unresolved_geometry"; break
			var filtered: Array=[]
			for candidate in query.events:
				if surfaces.has(ProjectileManager._surface_key(candidate)) and float(candidate.get("distance_m",INF))<=GameConfig.ARMOR_START_EPS_M: continue
				filtered.append(candidate)
			query.events=filtered
			var selection := ExternalContactSelector.select_contact(query); status=str(selection.status)
			if status=="vehicle": event=selection.event; distance=float(event.distance_m)
			elif status=="world": event=selection.contact; distance=float(event.distance_m)
			elif status=="unresolved": effect.reason="unresolved_geometry"; break
			var internal := DamageResolver.next_contact(query,eligible,seen,distance)
			if not internal.is_empty(): status="damage"; event=internal; distance=float(internal.distance_m)
		if loss>0 and distance*loss>=budget:
			var travel := budget/loss
			point+=direction*travel; effect.path.append(point); effect.distance_m+=travel; budget=0.0
			effect.reason="budget_exhausted"; break
		point+=direction*distance; remaining-=distance; budget=maxf(0,budget-distance*loss)
		effect.distance_m+=distance; effect.path.append(point); effect.remaining_mm=budget
		if status=="world": effect.reason="world"; break
		if event.is_empty(): effect.reason="range"; break
		if policy.is_valid():
			var allowed: Dictionary=policy.call({"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shooter_team_id":st.shooter_team_id},event.duplicate(true))
			if not live.call(st): return
			if not allowed.get("allow",false): effect.reason=allowed.get("reason","blocked_by_rules"); break
		event["geometry_frame"]=ShotRecordBuilder.capture_frame(st,event,snapshots)
		event["effect_channel"]="chemical_jet"; event["jet_distance_m"]=effect.distance_m
		event["jet_event_index"]=effect.contact_indices.size()+effect.damage_indices.size()
		if status=="damage":
			var result: Dictionary=commit_damage.call(st,event,budget,point,direction)
			if not live.call(st): return
			if not result.get("ok",false): effect.reason=result.get("reason","unresolved_damage"); break
			budget-=float(result.consumed_mm); seen[DamageResolver.item_key(event)]=true
		else:
			var result := ArmorResolver.resolve(event,direction,{"base_mm":budget,"impact_profile":st.impact_profile,"effect_policy":"chemical","caliber_mm":st.caliber_mm})
			budget=float(result.after_mm)
			# Commit the budget observation before a contact callback can cancel the carrier.
			effect.remaining_mm=budget
			var committed: Dictionary=commit_armor.call(st,event,result,point,direction)
			if not live.call(st): return
			if not committed.get("ok",false): effect.reason=committed.get("reason","unresolved_contact"); break
			surfaces.clear(); surfaces[ProjectileManager._surface_key(event)]=true
			if result.result=="penetrated": eligible[DamageResolver.target_key(event)]=not bool(result.backface)
			if not result.continue_flight: effect.reason="armor_"+str(result.result); break
		effect.remaining_mm=budget
		if budget<=0.00001: effect.reason="budget_exhausted"; break
		if remaining<=0.00001: effect.reason="range"; break
	effect.remaining_mm=budget; effect.complete=true
