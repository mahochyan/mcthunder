
## 5. CD08-T02 diagnostic: the decoupling RESOLVES every station, so the earlier loss came from somewhere else

### 5.1 Measured (probe builds its own actor; production code untouched)
```
D1 with the CURRENT state          : resolved **5 of 5** stations
D2 with a DECOUPLED snapshot       : resolved **5 of 5** stations, missed=[]
   people = person_1..person_5 ; assignments = assistant_driver->person_1 … driver->person_5
   each resolve returns crew_incapacitated with the right person_id
```
⇒ **The decoupled identity is sound on the resolution chain** (station → role → person) ✓✓. Nothing in the resolver breaks when a
person is named apart from the station, so the **−8 runtime assertions** seen in the reverted attempt did **not** come from
resolution.

### 5.2 What the search for the person-naming sites found
| site | verdict |
|---|---|
| `tests/run_damage_checks.gd:154,156` — `assign_crew("driver","commander")` | **the only delivered assertions that name a person by a role name**; these are the two the change must update |
| `tests/run_damage_checks.gd:169` — `person.id = "gunner"` | a `CrewStationDefinition`, i.e. a **station id**, which is legitimate and unaffected |
| `scripts/damage/vehicle_recovery.gd:158` — `assign_crew(state.action_target, state.action_person)` | already uses a **person id**, so it is compatible |
| 13 suites touching crew state | most only read `role_available` or land hits; the identity change has to be checked by running them, not by counting |
⇒ 2 assertions ≠ 8, so **the source of the loss is still not identified** and it is **not** guessed at.

### 5.3 Consequence
```
The task is now split cleanly:
  1. instrument the damage suite's OWN run so each assertion prints its label and the count is compared per block, which
     makes the missing eight appear one by one instead of being inferred;
  2. only then re-apply the decoupling together with the two delivered legs above, and re-run all thirteen suites that touch
     crew state rather than the five that were run before.
```
### 5.4 Standing lessons re-confirmed this round
```
· comparing RESULT COUNTS between runs, not just failures, is what caught a green run hiding a loss;
· a probe must build its own actor rather than assume a suite member (my earlier diagnostic failed on exactly that);
· the resolver path (station → role → person) is what the decoupling must preserve, and it is now measured to preserve it.
```
