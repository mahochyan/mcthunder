class_name FragmentSystem
extends RefCounted
## Finite synchronous ray effects. Uses production query, armor resolution and target damage transaction.
static func emit_bounded(st: ProjectileState, snapshots: Array, space: PhysicsDirectSpaceState3D, exclude: Array[RID], commit_damage: Callable, policy: Callable, live: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = st.seed
	var target := ShellEffectPolicy.target_snapshot(st.burst_target,snapshots)
	var eligible := {DamageResolver.target_key(st.burst_target):true}
	for index in ShellEffectPolicy.MAX_FRAGMENTS:
		if not live.call(st): return
		# Stratified sphere with seeded azimuth; all directions are fixed once and recorded.
		var z := 1.0-2.0*(float(index)+0.5)/float(ShellEffectPolicy.MAX_FRAGMENTS)
		var azimuth := rng.randf()*TAU
		var radius := sqrt(maxf(0,1-z*z))
		var direction := Vector3(radius*cos(azimuth),z,radius*sin(azimuth))
		var fragment := {"id":index,"direction":direction,"path":[st.position_world],"contacts":[],"damage_indices":[],"reason":"range","queries":0}
		st.fragments.append(fragment) # Commit actual partial path before any reentrant callback.
		var point := st.position_world
		var remaining := ShellEffectPolicy.FRAGMENT_RANGE_M
		var budget := ShellEffectPolicy.FRAGMENT_BUDGET_MM
		var seen := {}
		var surfaces := {}
		for iteration in ShellEffectPolicy.FRAGMENT_CONTACTS:
			if not live.call(st): return
			if not ShellEffectPolicy.inside(target,point+direction*ShellEffectPolicy.EPS*2):
				fragment.reason = "left_target"; break
			var leave := ShellEffectPolicy.exit_distance(target,point,direction,remaining)
			var ws := WorldQueryAdapter.query_world_stop(space,point,direction,remaining,exclude)
			if not ws.get("ok",false): fragment.reason = "unresolved_world"; break
			var qr := ShotQueryService.query({"query_id":"fragment_%d_%d_%d"%[st.projectile_id,index,iteration],
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
			if DamageResolver.target_key(event) != DamageResolver.target_key(st.burst_target): fragment.reason = "other_target"; break
			if policy.is_valid():
				var allowed: Dictionary = policy.call({"round_id":st.round_id,"shooter_id":st.shooter_id,"shooter_life_id":st.shooter_life_id,"shooter_team_id":st.shooter_team_id},event.duplicate(true))
				if not live.call(st): return
				if not allowed.get("allow",false): fragment.reason = allowed.get("reason","blocked_by_rules"); break
			event["geometry_frame"] = ShotRecordBuilder.capture_frame(st,event,snapshots)
			if status == "damage":
				var committed: Dictionary = commit_damage.call(st,event,budget,point,direction,index)
				if not live.call(st): return
				if not committed.get("ok",false): fragment.reason = committed.get("reason","unresolved_damage"); break
				budget -= float(committed.consumed_mm)
				seen[DamageResolver.item_key(event)] = true
			else:
				var resolved := ArmorResolver.resolve(event,direction,{"base_mm":budget,"scale":1.0,"consumed_mm":0.0,"ricochets":0})
				var recorded := event.duplicate(true)
				recorded.merge(resolved,true); recorded["point_world"] = point
				fragment.contacts.append(recorded)
				surfaces.clear(); surfaces[ProjectileManager._surface_key(event)] = true
				budget = float(resolved.after_mm)
				if not resolved.get("continue_flight",false) or resolved.result == "ricochet": fragment.reason = "armor_"+str(resolved.result); break
			if budget <= 0.00001: fragment.reason = "budget_exhausted"; break
			if remaining <= ShellEffectPolicy.EPS: fragment.reason = "range"; break
			fragment.reason = "contact_limit"
