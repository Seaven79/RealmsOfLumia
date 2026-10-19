# Realms of Lumia — Global Curve Lab v2 (spawn-only)

**Scope:** Server-authoritative global difficulty curves, not dynamic monster level scaling.
**Shortcut:** F7 or top-right CURVE LAB button, owner account only (UserId validated again on the server).
**Existing F8 dashboard:** Preserved. F8 values are the baseline. F7 curves multiply those baseline values.
**Balance config key:** `lumia_global_curves_v1` (JSON object in Creator Hub > Experience Configs).

## What is installed

- All monster IDs created via `MonsterService:SpawnMonster` share the same curve settings. Selecting a species in F7 only changes the *preview graph*. It does not restrict the global curve to that species.
- Global curve parameters for **Health**, **Damage**, **LevelXP**, **KillXP** and **Gold**. Neutral preset means no change to the previously balanced game.
- Monster HP/damage + kill XP/gold are calculated and *snapshotted at spawn*. Living monsters and existing encounters are never changed by a curve edit, test rollback, or config publication.
- Player XP requirement is read dynamically from `BalanceService`, and the UI receives change notifications. Changing it may update an XP bar mid-level: test carefully.
- An owner-only server-local **SERVER TEST** auto-applies after 0.55s idle when enabled; tests stop after 8 minutes or when the owner leaves. Only Studio/private-server testing is permitted. Click **REVERT TEST** to stop early.
- The server reads `lumia_global_curves_v1` with `ConfigService:GetConfigAsync()` and refreshes when `ConfigSnapshot.UpdateAvailable` fires. The current config is cached. If unavailable, original values remain active.
- **No in-game global publishing**, no embedded API token, and no change to player DataStore schemas.

## Important testing warning

The temporary curve reverts, **but XP and gold you earn do not revert**. Use a *test place / disposable testing profile* if testing rewards. An eight-minute timeout does not undo monster stats for already spawned mobs.

## First local test

1. Start Rojo: `cd C:\RobloxDevelopment\RealmsOfLumia` then `& 'C:\rojo\rojo.exe' serve default.project.json`.
2. Reconnect Rojo in Studio; stop/restart Play to load new scripts.
3. Open F7. The select-species arrows are **PREVIEW ONLY**.
4. In **Monster HP** set `Scale = 2.00`, keep other categories neutral. SERVER TEST defaults ON in Studio; wait for confirmation.
5. A living Lv1 Forest Wolf keeps its existing 65 HP (or F8-tuned value). Defeat it and wait for the respawn. The new wolf should have 130 HP if no F8 HP override.
6. Test another monster species (e.g. Dire Wolf) after it respawns: its HP should also double. F7 species selection has no effect on which mobs change.
7. Set HP Scale back to 1 or click REVERT TEST; **subsequent** spawns use the published/original curve. Existing wolves keep their spawn stats.
8. Verify rewards on a fresh monster. Kill XP/gold are locked at birth. Watch server Output for `[Lumia - Global Curves]` startup messages.

**Why changing Linear/Quadratic appears ineffective on level-1 wolves:** since `(level - 1)` is zero, only Scale changes their value. Use a level-4 Dire Wolf or level-5 boss to test the slope.

## Permanent updates on live servers (Creator Hub)

1. Publish this *code* change to the Roblox experience first, and update/restart old servers so they run the new `GlobalCurveConfig` script. Code doesn't hot-reload on old servers.
2. Open your experience in Creator Hub > **Configs** and create an **Experience Config**, key `lumia_global_curves_v1`, type **JSON**.
3. Start with the neutral example below; stage/test first. Do **not** publish experimental balance values directly to production.
4. Publish the config in Creator Hub. `ConfigService` notifies online servers; they refresh the snapshot and cache validated curves. It may take time for all servers to receive the update.
5. Only **future monster spawns** use the new config. No player kick/restart is needed for numerical config changes once every server has this code version.
6. To revert: Creator Hub > Configs > History > Restore previous config > Publish. Existing monsters remain unchanged until respawn.

**Neutral JSON example** (copy into the JSON config value):

```json
{
  "Version": 1,
  "Values": {
    "Health": {"Scale": 1, "Linear": 0.1, "Quadratic": 0.002},
    "Damage": {"Scale": 1, "Linear": 0.1, "Quadratic": 0.002},
    "LevelXP": {"Scale": 1, "Linear": 0.1, "Quadratic": 0.002},
    "KillXP": {"Scale": 1, "Linear": 0.1, "Quadratic": 0.002},
    "Gold": {"Scale": 1, "Linear": 0.1, "Quadratic": 0.002}
  }
}
```

To make every mob have **25% more HP at every level**, set only `Values.Health.Scale` to `1.25`, increase `Version` to `2`, and publish. Level stays fixed; each mob keeps its own original HP before the multiplier.

## Formula and numeric limits

`P(L,a,b) = 1 + a*(L-1) + b*(L-1)^2`

`multiplier = Scale * (P(L,Linear,Quadratic) / P(L,0.10,0.002)) ^ exponent`

Exponent: 0.85 for Damage, 1 otherwise. Health/XP/gold preserve each existing monster/type's base values, gear, and F8 overrides; values are bounded and validated on the server.

Scale must be between 0.25 and 3. Linear 0 to 0.4. Quadratic 0 to 0.02. Invalid/missing config data does not overwrite the last valid cached balance.

## Server security, persistence and performance

- F7 LocalScript only appears for UserId defined by `src/server/Admin/BalanceSettings.lua`, currently 1614020138; server RemoteFunctions also verify `player.UserId` and rate-limit changes. Studio/private server test required for mutations.
- One calculation per monster when it spawns, not every frame. Boss HP and attack remain fixed for each encounter. Gold/XP locked to monster's birth values.
- F8 separately stores persistent XP and mob tuning, which form the base stats. Changes to F8 may take effect differently; test precedence before production.
- XP/gold legitimately awarded during tests can persist through the normal PlayerPersistenceService.
- Published curves are **read-only** from game code. Update permissions stay in Creator Hub; no web/API keys embedded in scripts.
- In future, add balance release IDs, metrics and automated rollout checks before large deployments.

## Source integration

`GlobalCurveConfig.lua` (server): read/validate/refresh native Experience Configs.
`CurveLabService.lua` (server): pick published vs temporary test curve, validate and apply multipliers.
`CurveLabBridge.server.lua` (server): owner-only network and monster preview data.
`MonsterService.lua` (server): apply global HP/damage; snapshot XP/gold at spawn.
`ProgressionBridge.server.lua` (server): award XP/gold from the spawn snapshot.
`BalanceService.lua` (existing): F8 baseline and dynamic required XP, watches CurveLab.Changed.
`CurveMath.lua` (shared): formulas, presets, validation.
`LumiaCurveLab.client.lua` (owner-only client): graph/editor/launch button.

## Updates & rollback

The accompanying PowerShell installer checks source hashes, backs up every modified file, and refuses unknown versions. Use `-Rollback -BackupDir <printed backup folder>` before committing if Studio testing fails. A source rollback doesn't undo already earned XP/gold; those are normal persistent data.

Docs: https://create.roblox.com/docs/production/configs ; https://create.roblox.com/docs/reference/engine/classes/ConfigService
