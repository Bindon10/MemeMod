# MemeMod: Measure

A full rebuild of Chivalry: Medieval Warfare's melee combat, designed and implemented
without outside input. *Measure* is the fencing word for the distance and timing between
two fighters, and that's what the whole system is built around.

It uses only the game's existing animations: they're retimed, started part-way through,
or held on their last frame. Every hit decision is made by the server, with lag
compensation. All 41 vanilla melee weapons are ported. Build and test steps are in
`TESTING.md`.

---

## 1. Principles

1. **You can always read *what* is coming, and the skill is reading *when*.** Attack
   direction shows from the first frame of the windup. Timing can vary, but only within
   bounds a defender can learn.
2. **Actions cost time first and resources second.** A whiff loses you the exchange
   because you recover slowly, not because a bar drains.
3. **Defence has two tiers.** A precise parry wins the exchange. A held guard survives it
   but slowly loses.
4. **Simultaneity is resolved by rule, not luck.** Whoever committed first wins, and blades
   that meet clash.
5. **The server decides contact.** Clients only predict how it feels.
6. **Weapons differ in shape** (reach, arc, speed, mass), not in special-case code.

## 2. Anatomy of an attack

```
Ready --> Windup --(commit point)--> Strike --> Recovery --> Ready
            |                          |
            |-- feint --> Ready        |-- hit or block + queued attack --> next Windup (chain)
            |-- morph --> Windup       |-- hit or block + queued block  --> Guard
            |-- block --> Guard        |-- parried / clash / wall       --> Recoil
```

| Phase | Rules |
|---|---|
| **Windup** | Direction is visible at once. Before the **commit point** (60% of the windup) you can **feint** (back to Ready), **morph** (switch attack, keeping your windup progress), or **feint into guard** (press block). Each costs 10 posture. Ripostes, kicks and sprint attacks are committed from the first frame. |
| **Delayed release** | If the attack button (or a bound `MemeHold` key) is still held when the windup finishes, the swing waits in its last frame for up to 0.3 s and releases when you let go. Costs 6 posture. Not available on ripostes, kicks or sprint attacks. |
| **Strike** | The active window, swept on the server (§7). Turning is capped (§6). An attack pressed during a strike is queued as a chain. |
| **Recovery** | The vanilla length after a whiff, and 80% of it after contact with no chain. A whiffed kick takes at least 0.7 s. You can block only from halfway through recovery. Whiffs are meant to be punished. |
| **Chain** | Only after contact (a hit or a guard block). The next windup runs at 90% length, and alternating the same attack uses Chivalry's mirrored combo animations. You can't chain off a whiff. |

Morphing is new to Chivalry. Remote clients can only rebuild animations from vanilla data,
so the morphed windup restarts the target animation, compressed into the time you have left.
It reads as a fast re-windup, which also makes it readable.

The delayed release gives attackers timing variation the defender can learn to read: the
held frame is visible, it's capped, and it costs posture. Only Fire and AltFire send a
release, so mouse-wheel, stab and alt-attack binds can only hold with a `MemeHold` key
(`setbind <key> "MemeHold | OnRelease MemeHoldRelease"`). Bots delay some of their swings
too.

## 3. Defence

There's one button with two tiers. You block by looking at the incoming weapon: the
blade's midpoint has to be inside your view cone.

| Tier | When | Cone | Effect |
|---|---|---|---|
| **Parry** | The first 0.25 s after pressing | 60° | Perfect block. No posture cost, the attacker loses 8 posture and recoils for 0.6 s, and you have a 0.6 s **riposte** window |
| **Guard** | Still held after 0.25 s | 75° (shield: 85°) | Blocks for posture: 12 / 18 / 26 by the attacker's weapon mass (shields ×0.6). Move speed is ×0.75. The attacker rebounds (0.3 s) and can chain into you |
| **Drop** | Button released | — | 0.25 s if you blocked something, 0.4 s if you parried nothing |

- **Ripostes** start their windup at 60% length, are committed at once, and have
  hyper-armour through their strike.
- **Shields** skip the parry tier. They're guard-only, at reduced cost and with a wider cone.
- The **guard pose** is the vanilla `parryup` animation held on its last frame. Weapon
  animations use blend nodes, which hold their final pose until reset, so no new
  animation is needed.

## 4. Posture

Posture replaces stamina's combat role. It uses the existing `Stamina` value, so the
vanilla HUD bar and low-stamina breathing both work as posture cues.

| Event | Posture |
|---|---|
| Guard block | −12 light / −18 medium / −26 heavy (×0.6 on a shield) |
| Kick into guard | −35, plus a 0.55 s stagger |
| Being perfect-parried (attacker) | −8 |
| Feint, morph, feint into guard | −10 |
| Dodge, kick requirement | vanilla costs and gates |
| Regen | +25/s, starting 0.8 s after your last loss. None while guarding, attacking or staggered |
| **Hitting 0 while blocking** | **Guard break.** 1.1 s stagger with no block or dodge, then posture resets to 50% |

Whiffs cost no posture; they cost recovery time.

## 5. Hits, initiative and clash

| Defender's state | Result |
|---|---|
| Ready, windup, recovery, feint, recoil | Damage plus a 0.55 s stagger |
| Staggered | Damage only (no stun-lock), and you can block from halfway through any stagger |
| Striking, and released **more than 80 ms later** than the attacker | Damage, and the strike is **interrupted** |
| Striking, released earlier or within 80 ms | Damage only, a trade, and their strike continues |
| Riposte or sprint-attack strike | Damage only (hyper-armour) |
| Guarding, with the blade inside the cone | Blocked (§3) |
| Guarding, with the blade outside the cone | Damage plus a 0.55 s stagger |

- **Clash:** if two striking blades pass within 6 units of each other, both players recoil
  (0.45 s) and nobody takes damage.
- **Walls:** a blade that hits world geometry on two consecutive samples, after 15% of the
  strike, recoils (0.4 s). Destructible objectives still take damage.
- **Kicks:** a kick strikes once at 30% of its release animation, using the weapon
  attachment's vanilla kick sphere. On an unguarded target it does vanilla kick damage and
  a 0.7 s stagger. On a guard it costs 35 posture.
- **Damage numbers, location multipliers, decapitation, team damage and kill credit** are
  vanilla. Resolved hits go through vanilla `AttackOtherPawn` built on the server.

## 6. Bounded manipulation

Caps are fractions of each weapon's vanilla attack turn speed, so weapons keep their
relative feel (vanilla is roughly 250–410°/s).

| Phase | Yaw | Pitch |
|---|---|---|
| Windup | 100% | 100% (vanilla leaves windup pitch uncapped) |
| Strike (slash, overhead) | 85% | 85% |
| Strike (stab) | 75% | 85% |

Drags and accels still exist and still read, but are trimmed rather than removed.

## 7. Netcode: server-authoritative melee

**The server owns contact.** Clients never send hits; their melee claims are discarded.
Every server tick, for each striking pawn:

1. **Read the blade** from the server's animated weapon mesh, `TraceStart` to the last
   `TraceEnd*`. Dedicated servers already animate pawns (`bUpdateSkelWhenNotRendered`),
   which is how vanilla bots trace.
2. **Sweep it** between ticks with arc interpolation around the right shoulder: up to 6
   substeps, one per 15° of arc.
3. **Rewind candidates.** Each pawn's location and rotation are kept in a 32-entry history.
   Candidates are rewound by the attacker's round-trip time + 30 ms (capped at 250 ms), and
   12 bone capsules (head, neck, chest, belly, upper arms, forearms, thighs, shins) are
   rebuilt from the current pose placed at that rewound position.
4. **Test in order** each substep: blade vs blade (clash), then blade vs world (recoil),
   then blade vs capsules.
5. **Resolve.** Blocks read the defender's *live* state and view. Unblocked hits on a
   defender who could still be raising a block are **held** for that defender's one-way
   ping (capped at 80 ms). A block that arrives within the hold wins as a perfect parry.
   Nothing is ever played and then undone.

**Clients predict their own state machine.** The owning client and the server run the same
state machine from the same inputs (StartFire is replicated as usual).

- **Timing-dependent input checks** (commit point, riposte window) get 60 ms of slack on
  the server, plus the round trip for ripostes.
- **Server-forced events** (stagger, recoil, block and contact) arrive through reliable
  client RPCs on the weapon.
- **Chains need contact,** which only the server knows. When the server chains before the
  client heard about the hit, it pulls the client into the chain with an RPC.

**Rotation.** While winding up or striking, clients send moves at 60 Hz instead of the
hard-coded 20 Hz, so the server's blade follows your real aim.

**Hit stop.** On a confirmed hit, the attacker's swing plays at 0.3× speed for 60 ms on
every client, sent through a replicated counter. It's cosmetic only; the server's timing
doesn't pause.

## 8. Feedback

You should be able to read every exchange without the debug log.

| Moment | Everyone sees | You see |
|---|---|---|
| Perfect parry | Parry sparks at the blade (a guard block has none) | Defender: **PARRY** and the "combo ready" crosshair (riposte available). Attacker: **PARRIED** |
| Guard break | Long stagger | Defender: **GUARD BROKEN**. Attacker: **GUARD BREAK** |
| Posture drops below 30 | Vanilla low-stamina breathing | **POSTURE LOW** |
| Interrupt | Stagger | Victim: **INTERRUPTED**. Attacker: **INTERRUPT** |
| Clash | Both recoil | **CLASH** |

Words appear under the crosshair for 0.7 s, gold when it went your way and red when it
didn't. `MemeCues` turns them off.

## 9. Bots

`MemeAIController` (and `MemeAIDuelController` for duels) replaces vanilla's randomly
timed parries with a brain that reads the attacker's real windup. Skill (`fSkill`, 0–1)
scales everything.

- **Defence.** The bot picks the soonest windup aimed at it and plans a press:
  - **Parry:** timed so the parry window covers the expected contact, with a timing
    spread from ±0.2 s at skill 0 down to ±0.04 s at skill 1.
  - **Guard:** pressed early and held through the strike when the bot is unsure (more
    often at low skill), and always for shields.
  - Reaction time runs from 0.32 s down to 0.12 s. A morph re-plans the press only if
    the bot notices it.
- **Feints work on bots.** When the planned swing vanishes, skilled bots hold their
  block and the rest parry thin air and eat the missed-parry recovery.
- **Initiative.** If the bot's own strike will land first by more than 0.1 s, it keeps
  swinging. Otherwise it feints into guard, if it's still before its commit point.
- **Punishing.** It attacks into openings: whiffs, missed parries, staggers, recoils and
  feints. The chance of punishing runs from 35% at skill 0 to 95% at skill 1, after its
  reaction time.
- **Pressure.** Between openings it attacks on a rhythm of about one swing every 1.4 s at
  skill 0, down to 0.55 s at skill 1. The rhythm speeds up with aggression (`MAggression`,
  0.6 by default) and against targets low on posture. It won't start a swing that would
  trade into one already landing on it.
- **Offence.** It feints (up to twice in a row), morphs, delays some releases, and queues
  chains during the strike (they only fire on contact). It also ripostes after perfect
  parries, and kicks targets who are holding guard past the parry window, always once
  they're low on posture. Punishes skip the feints and delays.
- **Posture.** Below 30 posture it stops feinting, prefers parries to guard, and backs
  off.

Bots holding vanilla-only weapons (fists, flags, javelins) fall back to vanilla attack and
parry behaviour.

## 10. Weapons

`tools/port_weapons.py` generates, for each vanilla melee weapon:

- `MemeWeapon_X extends AOCWeapon_X implements(IMemeWeapon)`, which includes the shared
  state machine (`Include/MemeWeapon.uci`) and so inherits every vanilla animation, sound
  and damage value.
- `MemeWeaponAttachment_X`, so the attachment's `WeaponClass` points back at the Meme
  weapon (needed for animation rebuilding and for sheathed-weapon visuals).
- `AlternativeMode` remapped for the 1H/2H grip pairs (Longsword, Messer, Sword of War).
- `MemeFamilyInfo_{Agatha,Mason}_{Archer,ManAtArms,Vanguard,Knight}`, with every
  loadout slot remapped.

**Mass** sets block cost:

| Mass | Weapons |
|---|---|
| Light | daggers, knives, hatchet, cudgel, saber, Norse sword, mace, holy water sprinkler, falchion |
| Heavy | maul, zweihander, bardiche, halberd, pole hammer, double axe, grand mace, pick axe, greatsword, bearded axe, war hammer, Dane axe, pole axe |
| Medium | everything else |

**Excluded and left vanilla:**

- fists and flags (objective items),
- javelin and short spear melee (their throw alt-mode),
- every ranged, throwable and siege weapon.

These still work against Measure players. Their client-traced hits go through vanilla code,
and a Measure guard counts as a parry for them.

## 11. Tuning

Every number in this document is a tunable in `[MemeMod.MemeTuningConfig]` of `MemeMod.ini`,
listed there with a one-line comment. The server reads them at start-up and replicates
them, so clients predict with the server's values, even where an ini value happens to
match a client's built-in default.

- **Live:** `MemeTune` lists them all, `MemeTune <name>` shows one, and
  `MemeTune <name> <value>` changes it for everyone straight away. It needs admin on a
  server.
- **Permanent:** uncomment its `Tune=<name> <value>` line in `MemeMod.ini` and restart. Built-in defaults live in `MemeTuning` because UE3 ignores script defaults for ini-backed settings.
- **Source of truth:** `tools/gen_tuning.py` holds the list and its defaults, and
  regenerates `MemeTuning.uc`, the defaults and copy includes, and the ini section.

## 12. Not done, deliberately

- **Directional guard poses.** The view cone gives spatial blocking without new
  animations.
- **Mordhau-style chambers.** They'd need a mirrored-parry pose.
- **Per-class posture.** Class differences stay vanilla (health, speed, armour, dodge);
  posture is the same for everyone.
- **Bot movement.** Bots still use vanilla spacing and footwork, and only the decisions
  above are new.
