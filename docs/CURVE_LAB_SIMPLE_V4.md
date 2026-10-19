# Realms of Lumia — Simple Global Curve Lab (F7) v4

## Purpose

The Curve Lab is a **single global progression dial** for all monsters (regular, elite, bosses) spawned through the MMO `MonsterService`. It **does not level-scale creatures to players**: each monster retains its zone/definition level and unique base stats.

The v3 page containing dozens of stat entry fields is replaced by three presets and one numeric field. **The on-screen Curve Lab launcher is removed**. Only **F7** opens/closes the interface (owner only).

### Simple choices

| Choice | Curve strength | Meaning |
|---|---:|---|
| Gentle | 0.70 | Lower challenge, easier leveling |
| Classic | 1.00 | Original saved game balance; neutral |
| Hardcore | 1.40 | More difficult fights and slower leveling |
| Custom | 0.50 to 2.00 | Type any single strength number |

On Studio / private servers, selecting a preset or changing the number **automatically starts/refreshes an 8-minute local test** after a brief debounce. No Apply button is necessary. Click **REVERT** to end the local test; the automatic timer also reverts it. Other servers are not affected by a local test.

**Important:** Existing living monsters keep their stats, armor and rewards captured at spawn. The next spawn uses the new curve. If a wolf already has 65 HP, it remains at 65 until removed. `Respawn` changes apply when the next timer is scheduled. The player XP requirement can update immediately; XP/gold actually earned during a test may still be saved. Use test accounts / test place for reward experiments.

## What the one number changes

Internally the one number automatically generates all the existing v3 categories:

- Monster HP and attack damage
- Defense, attack cooldown and movement
- Detection, chase, wandering and attack reach (bounded)
- Respawn frequency
- XP needed to level up
- Kill XP and gold rewards (higher difficulty yields somewhat lower rewards)

The existing monster species tuning in F8 remains the baseline. Stats are capped by the server-side gameplay limits. Bosses still use their own HP/AI definitions. Player combat equipment and player HP are **not secretly scaled** by the Curve Lab; those systems are separate.

### Core math

The single `intensity` (0.5–2.0) produces 12 CurveMath entries. In each category:

```text
Scale      = 1 + (intensity - 1) * categoryScaleWeight
Linear     = 0.10 + (intensity - 1) * categoryLinearWeight
Quadratic  = 0.002 + (intensity - 1) * categoryQuadraticWeight

P(L,a,b) = 1 + a*(L-1) + b*(L-1)^2
factor = Scale * (P(L,Linear,Quadratic) / P(L,0.10,0.002))^exponent
```

Damage uses exponent 0.85, other categories 1.0. This ensures `1.00` has multiplier `1` at **every level**. At level 1, the `Scale` term still changes difficulty (an important improvement over changing just the curve slope).

The category weights are private balancing coefficients defined once in `src/shared/Progression/CurveMath.lua`. We can rebalance these *weights* as a versioned development update without making you edit 12 curves in F7.

## Backend architecture

```text
F7 owner LocalScript (presentation only)
  -> CurveLabBridge (verifies exact server-side owner UserId)
  -> CurveMath.FromIntensity(number) (server generates all 12 categories)
  -> CurveLabService (temporary, spawn-only override, auto expiry)
  -> MonsterService + SpawnManager + Guardian / outer-zone spawners
  -> ProgressionBridge / BalanceService
```

- `src/server/Admin/BalanceSettings.lua` contains the **only accepted owner UserId**. Client visibility checks are not authorization.
- Local tests are allowed only in Studio/private servers. Every TestIntensity request is bounded to 0.5–2.0 and verified server-side.
- We keep F8 as the existing fine-tuning tool. Manual overrides in F8 still affect original species baselines.
- Client-side F7 preview values cannot directly set server stats or manipulate persistence.

## Live production balancing (Experience Config)

The Roblox Experience Config key remains `lumia_global_curves_v1`. The v4 code adds this **simple** published JSON format:

```json
{
  "Version": 4,
  "Intensity": 1.20
}
```

Or to publish an exact preset:

```json
{
  "Version": 5,
  "Preset": "Hardcore"
}
```

Publisher authorization is managed in **Roblox Creator Hub/Studio**, not by an unprotected F7 remote. ConfigService reads the published values on each server, and the GlobalCurveConfig module subscribes to updates. **This requires publishing the new v4 game-code release before using the new Intensity/Preset JSON formats in production**. Existing v2/v3 `Values` dictionaries remain supported during migration.

Live config changes affect next monster spawns on each server without changing monsters that are already alive. New game *code* / world content still requires a normal Roblox Publish and a restart of outdated servers when appropriate.

## Local Studio verification

1. Stop Play. Install the v4 `.ps1` only after verifying its preview. It checks each source file hash against the attached Lumia(4) ZIP, backs up originals, and records a rollback manifest.
2. Start `& 'C:\rojo\rojo.exe' serve default.project.json` from the Lumia project root. Reconnect Rojo and restart Play.
3. Press **F7**. Confirm the on-screen Curve Lab launcher is **gone** and F8 still opens the original dashboard.
4. Select **Classic**: level-1 Forest Wolf still spawns with the baseline HP defined by F8/MonsterConfig (e.g. 65 HP if untuned).
5. Select **Hardcore**: preview updates immediately. Existing wolves stay unchanged; kill one and wait for respawn. The new wolf uses the new HP/damage curve. Other monster species use it too.
6. Enter **1.25** manually and press Enter / click outside: the test refreshes. Try Gentle and verify weaker future spawns.
7. Click **REVERT**. After a respawn, original/published values resume. Test expiry after eight minutes and owner departure.
8. Check Studio Output for `[Lumia - Curve Lab] v4 SIMPLE` and confirm no new red errors.
9. Test F7 with another UserId in a separate client: no window, and the server rejects direct RemoteFunction requests.

**Source/installer validation is not Roblox Studio runtime validation.** Do not publish to production until these checks pass.

## Rollback

The standalone installer prints its own timestamped backup directory. Pass that exact path back with `-Rollback -BackupDir ...` after stopping Play. The rollback refuses to overwrite files changed since installation. It restores the previous four scripts and removes only the guide it created.

Git checkpoints are recommended after a successful Studio test. The installer does not change Git history, profile schemas, or saved player progress.
