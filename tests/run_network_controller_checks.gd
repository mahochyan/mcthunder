extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1
	print(("[PASS] " if value else "[FAIL] ")+message)
func run() -> void:
	var world := NetworkBattleWorld.new(); root.add_child(world)
	check(world.ready_ok,"real authority world initialized without local controller or HUD")
	var presentation_nodes := 0
	var pending: Array[Node]=[world]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if node is Camera3D or node is HUD or node is PlayerController or node is AudioStreamPlayer3D or node is CombatFeedback: presentation_nodes+=1
		for child in node.get_children(): pending.append(child)
	check(presentation_nodes==0,"authority scene contains no Camera3D, HUD, local player or audio presenter")
	var actor: VehicleActor=world.actors[0]
	var controller := NetworkController.new(); controller.vehicle=actor; world.add_child(controller); actor.set_controller(controller)
	var command := VehicleCommand.new(); command.throttle=1; command.fire_requested=true
	var envelope := VehicleCommandCodec.encode(command,actor,0,Engine.get_physics_frames())
	check(controller.receive(envelope).ok,"validated remote envelope enters actual actor mailbox")
	check(not controller.receive(envelope).ok,"duplicate sequence rejected")
	for i in 8: await physics_frame
	check(actor.tank.forward_speed>0.1,"continuous throttle persists between packets")
	check(actor.gunner.shots_fired==1,"one fire edge produces exactly one actual launch")
	for i in 10: await physics_frame
	check(controller.held==null,"held input expires at server tick age limit")
	var expired_speed := actor.tank.forward_speed
	for i in 25: await physics_frame
	check(actor.tank.forward_speed<expired_speed,"packet loss releases throttle and vehicle coasts")
	var stale := VehicleCommandCodec.encode(command,actor,1,Engine.get_physics_frames())
	actor.reset_vehicle()
	check(not controller.receive(stale).ok and controller.held==null,"reset invalidates remote life state and retained input")
	var fresh := VehicleCommandCodec.encode(command,actor,0,Engine.get_physics_frames())
	check(controller.receive(fresh).ok,"fresh generation can submit again")
	var shots_before_detach := actor.gunner.shots_fired # Gunner retains its lifetime counter on reset.
	actor.set_controller(null)
	for i in 3: await physics_frame
	check(actor.gunner.shots_fired==shots_before_detach and controller.held==null,"detach discards staged fire and held throttle")
	world.free()
	print("=== 结果: %d 项检查, %d 失败 ==="%[checks,failures])
	print("NETWORK_CONTROLLER_CHECKS_PASS" if failures==0 else "NETWORK_CONTROLLER_CHECKS_FAIL")
	quit(0 if failures==0 else 1)
