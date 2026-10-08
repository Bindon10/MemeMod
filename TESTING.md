# MemeMod: test guide

What to build, what to try, and what each result tells us. The rules themselves are in
`DESIGN.md`.

**Status: none of this has been compiled.** Treat step 1 as a round trip: paste the build
log back and I'll fix it.

## 1. Build

1. Link the source into the SDK tree from an admin prompt:
   `mklink /J "F:\SteamLibrary\steamapps\common\chivalrymedievalwarfare\Development\Src\MemeMod" "C:\Projects\MemeMod"`
2. In `UDKGame\Config\UDKSDK.ini`, set `ModPackages=MemeMod`. (A second `ModPackages=`
   line builds both packages.)
3. Run `SDK - BUILD_SCRIPTS.bat`. Output goes to `UDKGame\ContentSDK\MemeMod.u`.
4. To confirm the package has the code, run
   `grep -a -c "MemeSweep" UDKGame\ContentSDK\MemeMod.u`. It should be non-zero.

If you change a weapon rule in `tools/port_weapons.py`, regenerate with:
`python tools\port_weapons.py "F:\...\Development\Src\AOC\Classes" C:\Projects\MemeMod`

## 2. Run

| Goal | How |
|---|---|
| Solo with bots | `SDK - Launch game sdkcontent.bat`, then `open AOCFFA-Moor_p?game=MemeMod.MemeModFFA`, then `addbots 2` |
| Duel | `?game=MemeMod.MemeModDuel` on a duel map |
| Team modes | `MemeModTD`, `MemeModLTS`, `MemeModTO` |
| Dedicated server | Add `?modname=MemeMod` to the map URL. The map prefix picks the game type (`AOCFFA`, `AOCTD`, `AOCLTS`, `AOCTO`, `AOCDUEL`, `AOCKOTH`, `AOCCTF`). The browser should list it as "MemeMod Measure 0.1" |
| Two clients plus latency | Listen or dedicated server; on each client run `net pktlag=120` (and `net pktlagvariance=20`) |

**Console commands:**

- `MemeDebug` (or `aoc_drawtracer 1` / `0`) toggles debug lines for your own swings. It
  works on dedicated servers too, after `adminlogin`: the server sends you the lines. It stays on across respawns,
  and each new swing clears the previous one.
  - **Orange:** the blade substeps the server tested.
  - **Cyan:** the rewound hit volumes of nearby pawns (capsule plus blade radius), every 0.1 s during your strike.
  - **Red sphere:** where the server registered contact.
  - **Combat log:** one chat line per contact you deal or take, saying what the server
    decided and why, for example
    `Bot1 -> You: HIT b_Neck, INTERRUPT, they released 140ms later, rewind 95ms`,
    `held 40ms, block arrived in time`, `BLOCKED, -18 posture, 42 left`, `CLASH`,
    `WALL`, `KICK into guard`. Paste these with any "that felt wrong" report.
- `MemeCues` toggles the words under the crosshair (PARRY, GUARD BROKEN and so on).
- `MemeTune` lists every tunable. `MemeTune <name> <value>` changes one live for everyone
  (admin on a server), for example `MemeTune MParryWindow 0.3` or `MemeTune MemeCueScale 1.5`.
- `MemeHold`: bind it with `setbind <key> "MemeHold | OnRelease MemeHoldRelease"` to delay
  any attack's release. Holding Fire or AltFire does the same without a bind.

## 3. Checklist, in order of risk

Each step depends on the ones above it, so stop at the first failure and send me what
you saw.

### A. Foundation (the risky bets)

1. **Loadout.** Every class shows its weapons with names and portraits, and you spawn
   holding them. Blank names mean the localization didn't inherit; tell me and I'll add a
   `MemeMod.int`.
2. **Swing animations.** Slash, alt slash, overhead, alt overhead and stab all play in
   first and third person, with no T-pose or frozen arms.
3. **Server sweep exists.** Run `MemeDebug` and swing near a bot. Orange lines should trace
   the blade's path. **If there are no lines,** the server can't read the attachment
   sockets; tell me the weapon.
4. **Sweep matches the visual.** The orange arc should overlap the visible blade. If it lags
   or sits offset from your swing, the server pose differs from the client's. This is the
   biggest risk in the design; describe which way it's off.
5. **Capsules sit on the body.** The cyan lines should cover the head, torso and limbs of
   the bot. Wrong bone names show up as missing pieces.
6. **Hits land.** Striking a bot does damage, plays blood, staggers it, and kills.
   Decapitation from neck hits still works.

### B. Decisions

7. **Commit point.** Press Q (feint) early in a windup and it cancels. Press it after about
   60% and it's refused (vanilla's failed-feint feedback).
8. **Morph.** During an early windup, press a different attack: the swing switches. Late
   in the windup, the second press is queued as a chain instead.
9. **Feint into guard.** RMB during an early windup goes straight into guard. Late in the
   windup, it does nothing until the swing ends.
10. **Chain.** Hit a bot and queue another attack: it chains without recovery, and the
    same attack twice alternates sides. Queue after a whiff and you get full recovery,
    then the buffered attack.
11. **Kick.** Kicking an unguarded target staggers it. A whiffed kick leaves you exposed
    for about 0.7 s.

### C. Defence and posture

12. **Parry.** Tap RMB as a bot's swing arrives. The bot recoils and you see the
    directional parry-hit animation. Attacking within about 0.6 s does a fast riposte.
13. **Guard.** Hold RMB. The pose holds and you move slower. Each blocked hit drains
    stamina (now posture), and the attacker bounces back.
14. **Spatial blocking.** Guard while looking away from a slash: it hits you. Look up for
    overheads.
15. **Guard break.** Let a heavy weapon chew through your guard. At zero you get a long
    stagger with no blocking, then posture comes back at half.
16. **Regen.** Posture refills about 0.8 s after you stop blocking or attacking, and not
    while you're guarding.

### D. Simultaneity (needs two humans)

17. **Initiative.** Both players swing. The one who released clearly first lands, and the
    other is interrupted with a stagger. Swings released together both land.
18. **Clash.** Mirror each other's slashes so the blades cross: both bounce, and there's no
    damage.
19. **Walls.** Slash into a wall in a corridor: you recoil. Gates and other destructibles
    still take damage.

### E. Latency (dedicated server, `net pktlag=120` on both clients)

20. **Defender's view.** A parry made as the blade visibly reaches you should succeed.
21. **Attacker's view.** Hits you see land should land. Report "I clearly hit them" misses,
    and "I was clearly blocking" hits, with the rough timing.
22. **Desync.** Watch for desync: a client stuck in a pose, or swings that start twice.
    Note what you pressed just before.

### F. Interop

23. **Vanilla weapons.** Javelins, flags, fists and ranged weapons still hit and can be
    blocked.
24. **Shields.** Shield weapons have guard only, with the wider cone.
25. **Grip switching.** Longsword, Messer and Sword of War still switch grip.
26. **KOTH and CTF.** Both load as MemeMod game types; flag carriers still swing the
    vanilla flag.

### G. Feedback and bots

27. **Delayed release.** Hold LMB through a slash: the swing should wait in its last
    windup frame and fire when you let go, or after 0.3 s. A quick click shouldn't delay at
    all. The combat log shows the posture drop.
28. **MemeTune.** Run `MemeTune MParryWindow 0.4` and feel parries get easier straight
    away. On a dedicated server, check a second client gets the change, then run
    `MemeTune` with no arguments to see the list.

29. **Cues.** A perfect parry shows sparks, **PARRY**, and the crosshair's combo state. A
    held-guard block shows none of those. Break a bot's guard and check **GUARD BREAK**.
30. **Bot parries.** `addbots 1` and swing at it: it should parry some swings and guard
    others. Its timing should vary, not be perfect.
31. **Bot feint bait.** Feint just before your commit point. Low-skill bots should often
    parry the air and get hit by your follow-up.
32. **Bot aggression.** Whiff near a bot, or parry nothing: it should punish most of the
    time at default skill. It should keep swinging steadily rather than standing around.
    `MemeTune MAggression 1` makes it relentless, and `0` puts it back near vanilla
    pacing.
33. **Bot offence.** Bots should sometimes feint, chain after hitting you, riposte after
    parrying you, and kick you when you hold guard.
34. **No stuck bots.** Watch for a bot frozen in guard or standing idle next to you. Note
    its weapon.

## 4. What to send back

- The build log (errors with line numbers refer to the generated class, so include the
  class name).
- `Launch.log`, for warnings mentioning `MemeWeapon`, `MemeModPawn` or
  `Accessed None`.
- For feel issues: weapon, attack, what you expected, what happened.

## 5. Tunables

Every tunable is listed, with a comment, in `[MemeMod.MemeTuningConfig]` of `MemeMod.ini`.

- **Try it live:** `MemeTune <name> <value>`. It lasts until the server restarts.
- **Keep it:** uncomment the line in `MemeMod.ini`, which sits next to `MemeMod.u` in the
  cooked folder, and restart.
- **Change a default** for everyone: edit `tools/gen_tuning.py` and run
  `python tools\gen_tuning.py .` from the mod root.
