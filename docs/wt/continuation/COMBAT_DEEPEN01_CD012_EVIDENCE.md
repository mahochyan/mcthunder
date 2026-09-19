
# MCT-COMBAT-DEEPEN-01 / WT-CD-012 evidence: optics, stabilisation, ranging and battle intelligence

## 0. Stage 0 — pickup check (verbatim from the packaged list)

```
07_WORK_ORDERS.json / items[11] (WT-CD-012):
  id=WT-CD-012 ; title=观瞄、稳定、测距与战斗情报 ; priority=P2 ; phase=G3 ; scope=core ; status=planned
  depends_on = **WT-CD-004, WT-CD-009, WT-CD-011**  ⇒ all three are CLOSED, so CD12 may proceed.
  related_parent_orders = WT-007 / WT-008 / WT-017 / WT-018
  basis = 已有观瞄与固定步机构；需要把观测、瞄具意图、炮管能力和可见情报进一步分开。
  player_outcome = 发现目标、建立射击条件、用烟幕脱离和依靠队友侦察成为有代价的战术选择。
  read_first = scripts/camera_rig.gd / scripts/turret_rig.gd / scripts/vehicle_actor.gd /
               scripts/battle/observation_policy.gd / scripts/battle/support_actions.gd / scripts/ui/battle_intel.gd
  source_ids = R08 / R10 / W06 / W07 ; acceptance_case_ids = CD12-T01 .. CD12-T06
```

### 0.1 The six cases, quoted
| case | title | action | expected |
|---|---|---|---|
| **CD12-T01** | 观察与炮塔分离 | 自由观察/望远镜后回炮镜 | **炮塔不被未授权观察强制转动** |
| **CD12-T02** | 稳定范围与机构 | 同起伏路有/无稳定及机构损坏 | **实际炮管跟随有配置限制，镜头选项不改变弹道** |
| **CD12-T03** | 测距/装定/遮挡 | 测距装定后在炮口前放真实障碍 | **发射路径仍受炮口遮挡，测距不穿墙** |
| **CD12-T04** | 烟幕与AI | 目标进入烟幕后改变位置 | **当前允许情报/AI跟踪按规则失效，不读取隐蔽真值** |
| **CD12-T05** | 侦察与最后目击 | 短暂暴露目标再遮挡并侦察 | **标记有来源和过期，last_seen不偷偷跟随** |
| **CD12-T06** | 低画质/缺装备/改键 | 切显示设置并使用未装备车辆 | **玩法遮蔽不变，无装备不提供假能力，提示读实际绑定** |

### 0.2 Rejection conditions carried forward verbatim
```
镜头不晃就称双轴稳定 ✗ · 侦察标记永久追踪隐蔽目标 ✗ · 低画质删除烟幕遮挡 ✗ · 靠新增热视按钮冒充传感器完成 ✗
```

## 1. Stage 2 — the named sources read, and the `basis` MEASURED rather than trusted

All six named files exist: `camera_rig.gd` (294 lines), `turret_rig.gd` (175), `vehicle_actor.gd` (509),
`battle/observation_policy.gd` (163), `battle/support_actions.gd` (240) and `ui/battle_intel.gd` (46).

### 1.1 The information permission skeleton ALREADY exists, and it is the shape the order asks for
`observation_policy.gd` already separates exactly the four levels the order names:
```
INFO_CLASSES   = ["world_truth","observer_visible","shared_intel","last_seen_memory"]
PRECISION_M    = {world_truth:0.0, observer_visible:2.0, shared_intel:15.0, last_seen_memory:25.0}
MEDIA          = ["none","smoke","foliage","building"]
CHANNELS       = ["optical","thermal"]
VIEWS          = ["player","ai","spectator","replay","killcam","minimap"]
INTERNAL_FIELDS= ["modules","crew","module_states","crew_states","ammo","inventory","shell","loadout"]
MEMORY_DEFAULT_S = 6.0 ; SHARED_INTEL_S = 12.0
```
It offers `attenuation(media, channel)`, `visual_blocked(media, channel)`, `blocks_projectile(media)`,
`precision_for(source)`, `expiry_for(source)`, `is_internal_field(key)` and `register_life(entity_id, life_id)`.

⇒ The class already carries per-source precision, per-source expiry and a rule that internal fields never leak, which is
precisely what the fourth and fifth design requirements ask for. CD12 therefore WIRES and VERIFIES this rather than inventing a
second perception system - which the order also forbids, since a shadow AI perception must not be created.

### 1.2 Smoke and scouting rules already exist per vehicle
`support_actions.gd` declares, per vehicle, `smoke {count, reload_s, cloud_radius_m, cloud_duration_s}` and
`recon {spot_duration_s, mark_precision_m}`, keeps one `smoke_clouds` array as the shared object and keeps
`recon_marks` as `entity_id -> {life_id, position, source, expires_at, precision_m}`.

⇒ A mark already carries its SOURCE and its EXPIRY, which is the fifth case expectation word for word, and the training hull
declares `aux_weapons []`, `smoke null` and `recon null`, so an unequipped vehicle is already denied the abilities rather than
given a fake version - the sixth case expectation.

### 1.3 Optics exist as a profile, but only for the historical pair
`configs/optics/` holds `m4a3_design.tres` and `m24_design.tres` only, while `optics_profile` is read in thirteen places,
including `camera_rig.gd:39` (the observation side) and `fire_control_state.gd:56` (the fire control side). The profile itself
declares `rangefinder_min_m`, `rangefinder_max_m`, `rangefinder_resolution_m`, `zeroing_step_m` and `zeroing_max_m`.

⇒ So the sight half of the separation exists and is shared between the camera and the fire control, which is what the second
design requirement wants. What is missing is a declared optics profile for the two engineering vehicles, so T01, T02 and T03
have nothing to differ by - and the pattern for adding one per vehicle was established and proven in CD11, where a declared
drive profile had to be added to exactly these two packets.

### 1.4 What the three separations look like today, and what must be measured
```
observation  : camera_rig.gd owns the view direction;
sight intent : optics_profile (fovs, offset, rangefinder, zeroing);
barrel       : VehicleCapabilities computes turret_scale, yaw_scale, pitch_scale and stabilizer_available per module state;
information  : observation_policy.gd classifies what a given observer is allowed to know.
```
The order asks for these to be INDEPENDENT, so the measurement is not whether each exists but whether moving one moves the
others. That is what the scenes must show, together with the second case explicit point that a camera or menu option must not
change the ballistic path.

## 2. Next steps
1. write the **acceptance scenes first**: free look and binocular then back to the sight with the turret untouched; the same
   rough ground with and without stabilisation and with the mechanism damaged; range, zero and a real obstacle at the muzzle;
   a target entering smoke and then moving; a brief exposure then cover with a recon mark; and a display setting change plus
   an unequipped vehicle;
2. declare an **optics profile per engineering vehicle** so the three cases have something to differ by, using the data path
   and the OPTIONAL-set lesson from CD11;
3. wire the existing observation policy, smoke and recon rules into the normal command and information interfaces, and emit
   committed events for loss of contact, expiry and mark source.
