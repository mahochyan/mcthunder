
## 6. The twelve missing assertions, named one by one (production-only decoupling)

### 6.1 The comparison that produced them
```
Run A (committed state)                    : 57 passes, 0 failures
Run B (decoupling applied to PRODUCTION ONLY): 45 passes, 2 failures
⇒ the ordered [PASS] labels were compared as SETS, so every leg that stopped appearing is listed rather than inferred.
   The earlier "eight" was a cruder count taken while my own suite edit was also in the tree; with production alone the
   loss is twelve.
```
### 6.2 GONE (12) — none of these appear at all any more
```
 1. living person can occupy another role
 2. one person never occupies two roles
 3. 90-degree turret uses actual rotated crew station
 4. rotated module and crew each receive exactly one path event
 5. damage record freezes actual part pose
 6. actual manager accepts damage shot            (appears twice in the baseline, both gone)
 7. destroyed turret drive blocks actual tracking
 8. missing loader changes real cooldown clock
 9. same damage event ID is rejected
10. damage callback reset terminates once
11. reset callback cannot leave late damage or duplicate finish
```
### 6.3 What this establishes
```
· The decoupling does NOT break resolution: five of five stations resolve in both states (previous section, measured).
· It DOES break the delivered suite's own flow: legs 3 to 11 belong to the later cases, and they stop being asserted at all,
  which means the suite stops walking those paths rather than merely reporting them failed. Legs 1 and 2 are the two places
  that pass a role name where a person identity belongs.
· Therefore this is not a defect in the decoupling to be argued away; it is a migration of a delivered expectation, exactly
  the class the package's rule change section describes, and it must be carried out as one change with before and after runs.
```
### 6.4 Next step, precisely
```
1. find EVERY place in the damage suite that names a person by a role or a station (not only the two assertions), because
   the later cases stop running and therefore hide their own naming sites;
2. decouple the identity and update those sites to read the person from the state (data driven, which is stronger than a
   hard coded name), in the same change;
3. run ALL THIRTEEN suites that touch crew state, not the five run before, and compare RESULT COUNTS as well as failures;
4. record it in the migration table with the before and after, and keep the rollback.
```
