# MemeMod

A rebuild of Chivalry: Medieval Warfare's melee combat. It extends vanilla `AOC` and is
independent of every other mod.

- `DESIGN.md`: the system and the reasoning behind it.
- `TESTING.md`: build, run, and what to look for.

## Layout

```
Classes/IMemeWeapon.uc                 interface the pawn uses to talk to any Meme weapon
Classes/MemeModPawn.uc                 posture, hit history, server sweep, resolution, hit stop
Classes/MemeMod{FFA,TD,LTS,TO,Duel,KOTH,CTF}.uc   game types
Classes/MemeAIController.uc            bot brain (MemeAIDuelController for duels)
Classes/MemeMod{...}PlayerController.uc    include MemeModPC.uci
Classes/MemeWeapon_*.uc                generated: vanilla weapon + MemeWeapon.uci
Classes/MemeWeaponAttachment_*.uc      generated: points WeaponClass at the Meme weapon
Classes/MemeFamilyInfo_*.uc            generated: loadouts remapped to Meme weapons
Include/MemeWeapon.uci                 the melee state machine
Include/MemeWeaponDefaults.uci         weapon state markers + tuning defaults (in each weapon)
Include/MemeModPC.uci                  turn caps, 60 Hz moves, MemeDebug/Cues/Hold/Tune
Include/MemeAI.uci                     Measure bot brain: timed parries, guard, feints, ripostes
Include/MemeAIDefaults.uci             generated: bot tunable defaults
Classes/MemeTuning.uc                  generated: replicated tunables from MemeMod.ini, MemeTune
Include/Meme*Tuning.uci, Meme*Sync.uci generated: tunable defaults and copy functions
Include/MemeGame.uci                   SetGameType: map prefix -> MemeMod game type
Include/MemeGameDefaults.uci           pawn class, families, display name
DefaultMemeMod.ini                     DefaultGame for ?modname=MemeMod, and every tunable
tools/port_weapons.py                  regenerates the weapon, attachment and family classes
tools/gen_tuning.py                    the tunables list; regenerates the tuning files and ini section
```

## UnrealScript rules this code follows

- No log macro (`LogInternal` is private under FINAL_RELEASE).
- No backticks except include lines.
- Vars before functions.
- `DefaultProperties` last.
