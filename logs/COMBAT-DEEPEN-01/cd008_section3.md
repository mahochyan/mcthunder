
## 3. Stage 0/2 continued — the contract scripts READ, and the order's `basis` MEASURED rather than trusted

### 3.1 What the order asserts, and what is actually there
| order's `basis` / requirement | measured reality (file:line) | verdict |
|---|---|---|
| a hit on a valid crew member sets `alive=false` directly | `scripts/damage/damage_resolver.gd:70-85` — a crew hit resolves `station_roles[station] → role`, then `crew_assignments[role] → person`, refuses with **`empty_station`** or **`missing_person`** by name, otherwise sets `out.after.alive = false` and returns **`crew_incapacitated`** | ✅ **confirmed**: one hit ⇒ `alive=false`, **no grading and no intermediate state** |
| injury, station and availability must be separated | `vehicle_runtime_state.gd:29-31` keeps `crew_states` / `crew_assignments` / `station_roles`; `:109-110` `assign_crew(role,person_id)` delegates to **`CrewRoster.assign`** | ⚠️ **already partly true** — person, station and role are **three separate maps** and a relief entry point already exists, which is **more** than the basis says |
| a versioned condition instead of one flag | `vehicle_runtime_state.gd:90` `crew_states[station.id] = {"alive":true,"original_role":…}`; `:98-100` `role_available(role)` returns person present **and `alive`** | ❌ **the gap**: condition is a **boolean**, so there is no light / serious / incapacitated state to grade |
| availability must not silently enable an unconfirmed middle penalty | `vehicle_capabilities.gd:45-51` derives `drive` from `role_available("driver")` and `fire` from `role_available("gunner")` | ✅ **already holds**: ability is driven by role availability, and **no penalty rate is applied anywhere** |
| recovery follows rules; the incapacitated do not revive | `vehicle_recovery.gd:11` returns for anything whose `kind != "module"` | ❌ **no crew recovery exists at all** ⇒ T04 must **implement it or explicitly configure its absence**, not assume it |
| old damage must not act on a new life | not yet measured | ⏳ next |

### 3.2 One inconsistency found while reading (named, not fixed blind)
```
`crew_states` is keyed by **station id** when it is built (vehicle_runtime_state.gd:90) while the resolver reads `people` by
**person id** (damage_resolver.gd:78-81). The same dictionary therefore carries two key meanings. That is a real hazard for
CD08-T02 (people and stations separating) and it is recorded here rather than changed on the spot, because the order's own
implementation step says to add the state transition and the legacy read first, and only then change the production resolver.
```

### 3.3 Consequences for the work (contract-first, no code touched this round)
1. **T01 (graded injury)** is the **core** work: replace the boolean with a **versioned** condition while keeping the legacy `alive` readable (T06).
2. **T05** starts from a **good** place: availability already follows role, and nothing applies an unconfirmed penalty ⇒ the case must **prove that stays true** after grading is added.
3. **T02** has an existing entry point (`CrewRoster.assign`) that must be **measured** (headcount conserved, old station emptied, injury following the person) before anything is changed.
4. **T03** needs a submission **identity** so a repeated event is not counted twice; check whether one exists at the commit path.
5. **T04** needs recovery to be either implemented with explicit configuration or **explicitly absent**, and the incapacity must persist within a life.
6. **T06** needs a **versioned migration** for legacy `alive` records, with a rollback.

### 3.4 Next round
Write the **acceptance scenes first** (per the order: 同一人多次受伤 / 换位 / 自然恢复 / 死亡重生), against the
measured baseline above, and only then change the resolver.
