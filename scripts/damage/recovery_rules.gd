class_name RecoveryRules
extends RefCounted
## Deterministic game rules, not historical vehicle performance.
const VERSION := "recovery-test-v1"
const EXTINGUISH_CHARGES := 2
const EXTINGUISH_SECONDS := 4.0
const REPAIR_SECONDS := 12.0
const REPAIR_TARGET := 0.5
const REPAIR_MAX_SPEED := 0.2
const REPLACEMENT_SECONDS := 8.0
const FIRE_IGNITION_INTEGRITY := 0.25
const FIRE_TICK_SECONDS := 1.0
const FIRE_MODULE_DAMAGE := 0.05
const FIRE_CREW_EXPOSURE_SECONDS := 20.0
const REPAIR_PRIORITY := ["track","breech","engine","transmission","turret_drive"]
const REPLACEMENT_PRIORITY := ["gunner","driver"]
const DONOR_PRIORITY := ["commander","assistant_driver_bow_gunner","loader"]
const WRECK_MAX_COUNT := 12
const WRECK_LIFETIME_SECONDS := 120.0
