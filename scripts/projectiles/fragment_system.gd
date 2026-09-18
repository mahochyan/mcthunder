class_name FragmentSystem
extends RefCounted
## Finite synchronous ray effects. Uses production query, armor resolution and target damage transaction.
static func emit_bounded(st: ProjectileState, snapshots: Array, space: PhysicsDirectSpaceState3D, exclude: Array[RID], commit_damage: Callable, policy: Callable, live: Callable, spall: Dictionary = {}, resolve_armor: Callable = Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = st.seed
	var directional := not spall.is_empty()
	var origin_target: Dictionary=spall.contact if directional else st.burst_target
	var target := ShellEffectPolicy.target_snapshot(origin_target,snapshots)
	var delayed := not st.fuze_policy.is_empty() or directional
	# CD07: an external HE bursts OUTSIDE a target, which breaks the assumption that a non-delayed effect happened inside
	# one. Such a burst therefore takes the same multi-target eligibility path as a delayed one, gated on the policy.
	var external_blast := st.effect_policy == "he_blast"
	var directions: Array[Vector3]=[]
	if directional: directions=SpallProfile.directions(spall.profile,spall.batch.direction,st.seed,int(spall.batch.id))
	var count: int=int(spall.profile.count) if directional else ShellEffectPolicy.MAX_FRAGMENTS
	for index in count:
		if not live.call(st): return
		# Stratified sphere with seeded azimuth; all directions are fixed once and recorded.
		var z := 1.0-2.0*(float(index)+0.5)/float(ShellEffectPolicy.MAX_FRAGMENTS)
		var azimuth := rng.randf()*TAU
		var radius := sqrt(maxf(0,1-z*z))
		var direction := Vector3(radius*cos(azimuth),z,radius*sin(azimuth))
		if directional: direction=directions[index]
		var fragment_id := st.fragments.size()
		var fragment := {"id":fragment_id,"direction":direction,"path":[st.position_world],"contacts":[],"damage_indices":[],"reason":"range","queries":0}
		if directional: fragment["spall_event_id"]=spall.batch.id; spall.batch.fragment_count+=1
		st.fragments.append(fragment) # Commit actual partial path before any reentrant callback.
		if directional and direction.dot(spall.contact.normal_world)>=-0.00001:
			fragment.reason="outward_from_plate"; continue
		var point := st.position_world
		var remaining := ShellEffectPolicy.FRAGMENT_RANGE_M
		var budget := ShellEffectPolicy.FRAGMENT_BUDGET_MM
		if directional: remaining=float(spall.profile.range_m); budget=float(spall.batch.allocated_mm)/count
		var seen := {}
		var surfaces := {}
		var eligible := {DamageResolver.target_key(origin_target):true}
		if directional: surfaces[ProjectileManager._surface_key(spall.contact)]=true
		if (delayed or external_blast) and not directional:
			eligible.clear()
			for snapshot in snapshots:
				# An external blast is NOT inside any target, so an inside test would leave the candidate set empty. For
				# that policy every supplied snapshot is a candidate; what a fragment actually strikes is still decided
				# by its ray and by world occlusion, which is what makes the wall matter.
				if snapshot is Dictionary:
					if external_blast or ShellEffectPolicy.inside(snapshot, point+direction*ShellEffectPolicy.EPS*2):
						eligible[DamageResolver.target_key(snapshot)] = true
		for iteration in ShellEffectPolicy.FRAGMENT_CONTACTS:
			if not live.call(st): return
			if not delayed and not external_blast and not ShellEffectPolicy.inside(target,point+direction*ShellEffectPolicy.EPS*2):
				fragment.reason = "left_target"; break
			var leave := INF if (delayed or external_blast) else ShellEffectPolicy.exit_distance(target,point,direction,remaining)
			var ws := WorldQueryAdapter.query_world_stop(space,point,direction,remaining,exclude)
			if not ws.get("ok",false): fragment.reason = "unresolved_world"; break
			var qr := ShotQueryService.query({"query_id":"fragment_%d_%d_%d"%[st.projectile_id,fragment_id,iteration],
				"physics_tick":Engine.get_physics_frames(),"from_world":point,"to_world":point+direction*remaining,
				"excluded_instances":[{"entity_id":st.shooter_id,"life_id":st.shooter_life_id}],
				"include_modules":true,"include_crew":true,"world_stop":ws.get("contact",{}) if ws.get("hit",false) else {}},snapshots)
			fragment.queries += 1
			if not qr.get("ok",false) or not qr.get("complete",false): fragment.reason = "unresolved_geometry"; break
			var filtered: Array = []
			for ev in qr.events:
				var key := ProjectileManager._surface_key(ev)
				if surfaces.has(key) and float(ev.get("distance_m",INF)) <= GameConfig.ARMOR_START_EPS_M: continue
				filtered.append(ev)
			qr.events = filtered
			var selection := ExternalContactSelector.select_contact(qr)
			var status := str(selection.get("status","unresolved"))
			var distance := remaining
			var event: Dictionary = {}
			if status == "vehicle": event = selection.event; distance = float(event.distance_m)
			elif status == "world": event = selection.contact; distance = float(event.distance_m)
			elif status == "unresolved": fragment.reason = "unresolved_geometry"; break
			var damage := DamageResolver.next_contact(qr,eligible,seen,distance)
			if not damage.is_empty(): status = "damage"; event = damage; distance = float(event.distance_m)
			if leave < distance-ShellEffectPolicy.EPS:
				fragment.path.append(point+direction*leave); fragment.reason = "left_target"; break
			point += direction*distance
			remaining -= distance
			fragment.path.append(point)
			if status == "world": fragment.reason = "world"; break
			if event.is_empty(): fragment.reason = "range"; break
			if not delayed and DamageResolver.target_key(event) != DamageResolver.target_key(st.burst_target): fragment.reason = "other_target"; break
			if policy.is_valid():
				var allowed: Dictionary = policy.call({"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shooter_team_id":st.shooter_team_id},event.duplicate(true))
				if not live.call(st): return
				if not allowed.get("allow",false): fragment.reason = allowed.get("reason","blocked_by_rules"); break
			event["geometry_frame"] = ShotRecordBuilder.capture_frame(st,event,snapshots)
			if status == "damage":
				var committed: Dictionary = commit_damage.call(st,event,budget,point,direction,fragment_id)
				if not live.call(st): return
				if not committed.get("ok",false): fragment.reason = committed.get("reason","unresolved_damage"); break
				budget -= float(committed.consumed_mm)
				seen[DamageResolver.item_key(event)] = true
			else:
				event["armor_trace"]="fragment_%d_%d"%[fragment_id,fragment.contacts.size()]
				var armor_budget := {"base_mm":budget,"scale":1.0,"consumed_mm":0.0,"ricochets":0,
					"impact_profile":spall.profile.fragment_impact_profile if directional else ArmorImpactProfile.fragment_profile(st.impact_profile),"fragment":true}
				var resolved: Dictionary=resolve_armor.call(st,event,direction,armor_budget) if resolve_armor.is_valid() else ArmorResolver.resolve(event,direction,armor_budget)
				if not live.call(st): return
				var recorded := event.duplicate(true)
				recorded.merge(resolved,true); recorded["point_world"] = point
				fragment.contacts.append(recorded)
				surfaces.clear(); surfaces[ProjectileManager._surface_key(event)] = true
				budget = float(resolved.after_mm)
				if delayed and resolved.result == "penetrated":
					eligible[DamageResolver.target_key(event)] = not bool(resolved.backface)
				if not resolved.get("continue_flight",false) or resolved.result == "ricochet": fragment.reason = "armor_"+str(resolved.result); break
			if budget <= 0.00001: fragment.reason = "budget_exhausted"; break
			if remaining <= ShellEffectPolicy.EPS: fragment.reason = "range"; break
			fragment.reason = "contact_limit"
