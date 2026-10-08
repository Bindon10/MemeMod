MemeMod (Measure): what differs from vanilla combat
====================================================

Condensed summary. Full rules and numbers are in DESIGN.md.

Unchanged from vanilla: damage values, hit-location multipliers, decapitation,
health, speed, armour, dodging, class differences, and ranged and siege weapons.


1. WHO DECIDES HITS
-------------------

  Vanilla:  Your own client traces the blade and tells the server what you hit.
  MemeMod:  The server traces every swing itself, rewinding targets by your
            ping. Melee hits reported by clients are ignored.


2. ATTACKING
------------

  Feint
    Vanilla:  Any time during the windup.
    MemeMod:  Only before the commit point (60% of the windup).
              Costs 10 posture.

  Morph (new)
    Press a different attack early in the windup to switch to it,
    keeping your windup progress. Costs 10 posture.

  Feint into block (new)
    Press block early in the windup to drop straight into guard.
    Costs 10 posture.

  Combos
    Vanilla:  Chain whether or not you hit.
    MemeMod:  Chain only after contact (a hit or a blocked hit).
              The chained windup runs at 90%. Repeating the same attack
              alternates sides.

  Whiffs
    Vanilla:  Cost stamina.
    MemeMod:  Free, but you get the full recovery time.
              Recovery after contact is 80%.
              A whiffed kick leaves you open for at least 0.7 s.

  Delayed release (new)
    Keep the attack button held as the windup finishes and the swing waits
    in its last frame, for up to 0.3 s, until you let go. Costs 6 posture.
    Mouse-wheel and stab binds need a key bound to MemeHold for this:
      setbind <key> "MemeHold | OnRelease MemeHoldRelease"

  Aim during a swing
    Vanilla:  Per-weapon turn cap.
    MemeMod:  Same cap during the windup. 85% of it during the strike
              (stabs turn sideways at 75%).


3. DEFENCE
----------

  Block button
    Vanilla:  A single timed parry (shields can hold).
    MemeMod:  Two tiers on one button:
                - Perfect parry: the first 0.25 s after pressing.
                - Guard: still held after that.

  Perfect parry
    - Costs you no posture.
    - The attacker loses 8 posture and recoils for 0.6 s.
    - You get a 0.6 s window for a fast riposte.

  Held guard (new for weapons)
    - Blocks for 12 / 18 / 26 posture, by the attacker's weapon weight
      (light / medium / heavy).
    - You move at 75% speed while guarding.
    - The attacker bounces off and can chain into you.

  Where you look matters
    Vanilla:  Generous parry box.
    MemeMod:  The incoming blade has to be inside your view cone:
              60 degrees for a parry, 75 for a guard, 85 for a shield.

  Shields
    Guard only (no perfect parry), with a wider cone and 60% of the
    posture cost.

  Missed parry
    You're exposed for 0.4 s. It's 0.25 s if you actually blocked something.


4. STAMINA BECOMES POSTURE
--------------------------

  - It's still the vanilla stamina bar.
  - It drains only from blocking, kicks into guard, being parried, and
    feints or morphs. Swinging is free.
  - It regenerates at 25 per second, starting 0.8 s after your last loss,
    and not while you're guarding.
  - Guard break: hitting 0 while blocking means a 1.1 s stagger with no
    blocking, after which posture resets to 50%.


5. WHEN TWO PEOPLE SWING AT ONCE
--------------------------------

  Initiative   If you started your strike more than 80 ms before them,
               your hit interrupts them with a stagger. Closer than that,
               both hits land.

  Clash        Blades that cross bounce both players back. Nobody takes
               damage.

  Walls        A blade that hits geometry recoils you. Destructible
               objectives still take damage.

  No stun-lock An already-staggered player takes damage but isn't
               staggered again. Ripostes and sprint attacks can't be
               interrupted.

  Kicks        An unguarded kick staggers for 0.7 s. A kick into guard
               costs 35 posture.


6. FEEL AND FEEDBACK (ALL NEW)
------------------------------

  - Hit stop: a brief slow-down of your swing when it connects.
  - Perfect parry: parry sparks (a held guard shows none), and the
    combo-ready crosshair to signal the riposte window.
  - Cue words under the crosshair: PARRY, PARRIED, GUARD BREAK,
    GUARD BROKEN, POSTURE LOW, INTERRUPT, INTERRUPTED, CLASH.
    The console command MemeCues turns them off.
  - Debug tools: MemeDebug (or aoc_drawtracer 1) shows the server's
    sweep and hitboxes plus a combat log. Works on dedicated servers.


7. BOTS
-------

  - They read your real windup and time parries by skill level.
  - They can be baited by feints.
  - They feint, morph, delay releases, chain, riposte, kick held guards,
    and back off when low on posture.
  - They punish openings (whiffs, missed parries, staggers) and keep up
    steady pressure instead of vanilla's once-a-second decision.
    MemeTune MAggression <-1..1> sets how relentless they are.


8. SERVER AND GAME MODES
------------------------

  - All seven game types run as MemeMod via ?modname=MemeMod:
    FFA, TD, LTS, TO, Duel, KOTH, CTF.
  - An FFA round where nobody has scored restarts the clock instead of
    going into endless sudden death.
  - Every number is a tunable in [MemeMod.MemeTuningConfig] of MemeMod.ini.
    Admins change them live with: MemeTune <name> <value>
    (MemeTune on its own lists them all.)
  - Debug draw on a dedicated server needs adminlogin.


9. LEFT VANILLA
---------------

  Fists, flags and javelin melee. They still work against MemeMod players,
  and a MemeMod guard counts as a parry against them.
