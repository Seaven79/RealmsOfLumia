# Global Tuning & Admin Panel

Living reference for the balance system. Read this before changing curve code.

**Files**

| File | Role |
|---|---|
| `src/shared/Admin/GlobalTuning.lua` | Single source of truth for dials + presets |
| `src/shared/Admin/AdminSchema.lua` | Authoring fields (labels, ranges, defaults) |
| `src/server/Admin/AdminBridge.server.lua` | The only writer. Owner-gated |
| `src/server/Admin/BalanceService.lua` | Persistence + effective-value getters |
| `src/server/Admin/MobTuningService.lua` | Per-monster stats + loot (pre-existing) |
| `src/client/Admin/LumiaAdminKit.lua` | Reusable widget library |
| `src/client/Admin/LumiaAdminPanel.client.lua` | Panel UI (schema-driven) |

---

## The three layers

```
AUTHORING value   →   GLOBAL dials   →   EFFECTIVE value
what you type          multipliers        what the game reads
(stored, never         (stored)            (computed on read)
 multiplied)
```

**Dials multiply on read.** They never rewrite authoring values. Two consequences
that everything else depends on:

- Applying a preset twice == applying it once (no compounding).
- Setting every dial to `1.00x` restores the shipped balance exactly.

If you ever "optimise" this by applying a multiplier to the stored value, you
break both properties and save files become unrecoverable. Don't.

## Where each dial is applied

| Dial | Applied in | Function |
|---|---|---|
| `Difficulty` | `MonsterService:SpawnMonster` | trash HP + damage |
| `BossScale` | `MonsterService:SpawnMonster` | boss HP + damage (`IsBoss == true`) |
| `PlayerDamage` | `SwordCombatService` (`_onAttack`, `_onFistAttack`) | all outgoing player damage: weapons and fists |
| `PlayerArmor` | `CombatStats.IncomingDamage` (cached) | effective defense, i.e. damage taken |
| `MobRewards` | `MonsterService` (spawn snapshot), `ProgressionBridge` (legacy fallback) | kill XP + gold |
| `QuestRewards` | `QuestService:TurnIn` via `GetEffectiveQuestReward*` | quest XP + gold |
| `LevelPace` | `BalanceService:GetRequiredXP` | XP required per level |

## The combat equation

```
player hit  = floor((weapon.Damage + attackStat) * PlayerDamage) clamped >= 1
mob health  = config.MaxHealth * (boss and BossScale or Difficulty)
hits to kill = ceil(mob health / (player hit / mob defense factor))

damage taken = ceil(mob damage * (1 - mitigation))
mitigation   = defense*PlayerArmor / (defense*PlayerArmor + 92) + set bonus (max 72%)
```

`PlayerArmor` scales **effective defense**, so it rides the existing diminishing
returns curve and can never reach 100% mitigation. Adding a flat bonus instead
would make armour dials unsafe at high values.

`PlayerDamage` is applied after gear and level stats, so one dial covers the
whole loadout rather than one tier — that is what stops a new sword from
trivialising content.

`CombatStats` caches the armor dial and refreshes on `BalanceService.Changed`,
because `IncomingDamage` runs on every monster hit and must not reach into the
balance service (or its DataStore load) per hit.

The panel's preview shows `≈N hits (X each)` per monster, computed with the same
formula from that tier's shop sword — so "does this kill too fast" is answerable
before playing.

Monster stats and rewards are **snapshotted at spawn** into attributes
(`LumiaSpawnXP`, `LumiaSpawnGold`, `MaxHealth`). A living monster never changes
mid-fight; new spawns pick up new dials.

## Adding a dial (3 steps)

1. Add an entry to `GlobalTuning.Dials` — `Id`, `Label`, `Hint`, `Min`, `Max`,
   `Step`, `Default`, `Unit`. It renders and validates automatically.
2. Read it where it belongs: `BalanceService:GetGlobal("YourDial")`.
3. If it must affect stored data, apply it in a **getter**, not a setter.

Add it to a preset in `GlobalTuning.Presets` if it should be covered by templates.

## Adding an authoring field (3 steps)

1. `Schema.AddField{ Id=..., Section=..., Category=..., Key=..., Label=...,
   Min=..., Max=..., Integer=true, Default=... }` in `AdminSchema.lua`.
2. Add a matching branch in `AdminBridge.server.lua` for that `Category`
   (both the write and the read in `currentValue`).
3. Done — the client renders it, the server validates it, and resets work.

Sections with `Hidden = true` stay in the schema (so the server keeps validating
them) but are not shown in the panel.

## Persistence

| Data | DataStore key | Service |
|---|---|---|
| Level XP, quest rewards, monster XP, global dials | `SharedBalance_v1` | `BalanceService` |
| Per-monster stats + loot weights | `MobTuning_v1` | `MobTuningService` |

Both use `UpdateAsync` + `MessagingService` for cross-server propagation.

**Overrides beat config.** If a value looks wrong after a config edit, a stored
override is winning. Clear it from the panel's reset button, or wipe the key in
Studio. The panel shows an amber bar on overridden fields.

## Owner gate

`BalanceSettings.OwnerUserId` — a numeric UserId, never a display name. The
bridge checks it **before anything else** and returns no data to anyone else.
The client makes zero requests until the panel is opened.

## Tools section (maintenance)

`Reset level and XP` sets the **calling owner's** `Character.Level = 1` and
`Experience = 0` and pushes a fresh snapshot to the XP bar. It does not touch
gold, inventory, quests or achievements.

Two safety properties, both deliberate:

- The handler acts on `player` (the caller) only, never on a target argument, so
  even a forged request cannot reset another player.
- The button arms on the first click and commits on a second click within 5
  seconds, so a stray click cannot wipe progress.

Server path: `AdminBridge.handlers.ResetLevel` → `ProgressionService:ResetProgress`
→ `ProgressionNetwork.ProgressionChanged`. It is audit-logged like any write.

## Known limits

- Dials affect **newly spawned** monsters only.
- Balance writes need *Studio → Game Settings → Security → Enable Studio Access
  to API Services*, or the panel reports "balance NOT saving".
- `CurveLabService` still exists for published-config preview but its UI is
  hidden: the dials supersede it (they persist and are reversible).
- `GetQuestXP(tier)` (Starter/Side/Main) is legacy and unused by `QuestService`.
  Per-quest rewards are the real control.

## Scalability notes

- No per-frame work anywhere in the admin stack. The panel renders on demand and
  had its background ticker removed.
- Server work is owner-triggered only; 15 requests/sec cap, 200 ops per batch.
- Effective-value getters are table lookups — safe to call from hot paths
  (`GetRequiredXP` runs on every XP award).
- `BalanceService:PreviewTuning` walks 4 monsters; only called for panel state.

---

# Shop collision

Furniture in the shop is server-built (`LumiaMerchant.server.lua`) with
`CanCollide` on counters, shelves and crates. Solid parts stop a player walking
*through* them, but a 2.9-stud counter can still be jumped onto.

Invisible `blocker(...)` volumes are placed above every walkable-height fixture:

- `CanCollide = true` — the body cannot enter, so it cannot be stood on
- `CanQuery = false` — excluded from every raycast (decor passes stay correct)
- `CanTouch = false` — no `Touched` connections can ever fire
- tagged `LumiaFurnitureBlocker` so future systems can find them

This is static geometry: zero scripts, zero per-frame cost, scales to any player
count. When adding furniture, add a matching blocker.
