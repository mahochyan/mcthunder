class_name GameConfig
const ARMOR_RULES_VERSION := "armor-test-v1"
const DAMAGE_RULES_VERSION := "direct-hit-test-v1"
const DAMAGE_MODULE_INTEGRITY := 100.0
const DAMAGE_MODULE_RESISTANCE_MM := 10.0
const DAMAGE_CREW_RESISTANCE_MM := 2.0
const DAMAGE_MISSING_LOADER_RATE := 1.0 / 1.6
const DAMAGE_MIN_CREW := 2
const DAMAGE_MAX_CONTACTS := 64
const ARMOR_RICOCHET_DEG := 75.0
const ARMOR_RICOCHET_SPEED_SCALE := 0.6
const ARMOR_RICOCHET_BUDGET_SCALE := 0.5
const ARMOR_MAX_RICOCHETS := 1
const ARMOR_GRAZING_COS := 1e-6
const ARMOR_START_EPS_M := 1e-5
const ARMOR_CONTACTS_PER_STEP := 8
const ARMOR_CONTACTS_PER_SHOT := 32
## 集中配置：所有可调参数与约定。
## 世界约定：1 单位 ≈ 1 米；Y 轴向上；车辆前方为 -Z。
## 碰撞层约定（集中说明）：
##   LAYER_WORLD   = 1  （bit1）：地面 / 围墙 / 箱子 / 靶板等静态世界
##   LAYER_VEHICLE = 2  （bit2）：本车（CharacterBody3D）
##   射击/相机射线 mask = WORLD | VEHICLE，并一律 exclude 本车 RID。
## 视觉层约定（MeshInstance3D.layers，与碰撞层独立）：
##   VIS_LAYER_VEHICLE = 2：本车全部网格；炮镜相机 cull_mask 剔除该位，
##   因此炮镜不会看到/被自身模型挡住；第三人称相机保留该位。

# --- 驾驶（工作单初始参数，非性能数据） ---
const FORWARD_MAX_SPEED := 8.0   # 前进最高 m/s
const REVERSE_MAX_SPEED := 3.0   # 倒车最高 m/s
const FORWARD_ACCEL := 6.0       # 前进加速度 m/s^2
const REVERSE_ACCEL := 4.0       # 倒车加速度 m/s^2
const BRAKE_DECEL := 10.0        # 反向输入时的制动 m/s^2
const COAST_DECEL := 3.0         # 松开按键滑行减速 m/s^2
const HULL_TURN_SPEED := 75.0    # 车体转向 deg/s（允许原地转向，无平移）
const GRAVITY := 18.0            # 简化重力，保证贴地不穿地
const DRIVE_MAX_SLOPE_DEG := 28.0
const DRIVE_FLOOR_SNAP_M := 0.4
const DRIVE_PROBE_UP_M := 1.6
const DRIVE_PROBE_DOWN_M := 1.8
const DRIVE_POSE_DEG_PER_SECOND := 120.0
const DRIVE_COLLISION_SIZE := Vector3(2.6,1.5,4.2)
const DRIVE_COLLISION_CENTER := Vector3(0,0.75,0)

# --- 瞄准与相机 ---
const TURRET_YAW_SPEED := 35.0   # 炮塔回转上限 deg/s（不瞬间旋转）
const TURRET_PITCH_SPEED := 30.0 # 炮管俯仰速度 deg/s
const BARREL_PITCH_MIN := -8.0   # 炮管俯角下限 deg
const BARREL_PITCH_MAX := 20.0   # 炮管仰角上限 deg
const MOUSE_SENS := 0.0035       # 鼠标灵敏度 rad/px
const CAM_PITCH_MIN := -55.0     # 观察俯角下限 deg
const CAM_PITCH_MAX := 40.0      # 观察仰角上限 deg
const CAM_DISTANCE := 7.0        # 第三人称跟随距离 m
const CAM_HEIGHT := 2.4          # 第三人称相机抬高 m
const MAIN_FOV := 70.0
const SIGHT_FOV := 30.0          # 炮镜视场角

# --- 射击 ---
const RELOAD_TIME := 2.0         # 装填冷却 s（按住不绕过）
const GUN_RANGE := 200.0         # 射线射程 m
const RESUME_GRACE := 0.25       # 暂停恢复后的开炮宽限 s（防误击发）

# --- 碰撞层（集中约定） ---
const LAYER_WORLD := 1        # bit1：地面 / 围墙 / 箱子 / 靶板等静态世界
const LAYER_VEHICLE := 2      # bit2：本车（CharacterBody3D）
const VIS_LAYER_VEHICLE := 2  # 视觉层 bit：本车网格；炮镜相机 cull_mask 剔除该位
const VIS_LAYER_VEHICLE_B := 4  # 003：B 车视觉层 bit——炮镜只剔除本车层，不隐藏其他车

# --- 输入动作名（project.godot 已注册全部映射） ---
const ACTIONS := ["move_forward", "move_back", "turn_left", "turn_right", "fire", "aim", "reset", "pause", "debug_toggle"]
