"""Generates the MemeMod tuning plumbing from one list.

Writes Classes/MemeTuning.uc, the *Tuning.uci default files, the *Sync.uci copy
functions and the [MemeMod.MemeTuning] section of DefaultMemeMod.ini.
Usage: python gen_tuning.py <MemeMod root>
"""
import os
import sys

# (name, type, default, owner, ini comment). Owner: W weapon, P pawn, A bot.
T = [
    ("MCommitFraction", "float", 0.6, "W", "windup fraction after which feints and morphs are refused"),
    ("MServerCommitSlack", "float", 0.06, "W", "server grace on timing checks (s)"),
    ("MChainWindupScale", "float", 0.9, "W", "chained windup length scale"),
    ("MRiposteWindupScale", "float", 0.6, "W", "riposte windup length scale"),
    ("MRiposteWindow", "float", 0.6, "W", "time after a perfect parry to start a riposte (s)"),
    ("MParryWindow", "float", 0.25, "W", "perfect parry window after pressing block (s)"),
    ("MContactRecoveryScale", "float", 0.8, "W", "recovery scale after contact"),
    ("MKickWhiffRecovery", "float", 0.7, "W", "minimum recovery after a whiffed kick (s)"),
    ("MRecoveryParryFraction", "float", 0.5, "W", "recovery fraction after which block is allowed"),
    ("MGuardMoveScale", "float", 0.75, "W", "move speed while guarding"),
    ("MGuardDropTime", "float", 0.25, "W", "guard drop after blocking something (s)"),
    ("MMissedParryRecovery", "float", 0.4, "W", "guard drop after blocking nothing (s)"),
    ("MFeintTime", "float", 0.2, "W", "feint recovery (s)"),
    ("MFeintCost", "float", 10.0, "W", "posture cost of feint, morph, feint into guard"),
    ("MStaggerHit", "float", 0.55, "W", "stagger from an unblocked hit (s)"),
    ("MStaggerKick", "float", 0.7, "W", "stagger from an unguarded kick (s)"),
    ("MStaggerBreak", "float", 1.1, "W", "stagger from a guard break (s)"),
    ("MStaggerParryFraction", "float", 0.5, "W", "stagger fraction after which block is allowed"),
    ("MWindupTurn", "float", 1.0, "W", "windup turn cap, fraction of vanilla"),
    ("MStrikeTurn", "float", 0.85, "W", "strike turn cap, fraction of vanilla"),
    ("MStabStrikeTurn", "float", 0.75, "W", "stab strike sideways turn cap, fraction of vanilla"),
    ("MHoldMax", "float", 0.3, "W", "longest delayed release (s), 0 disables"),
    ("MHoldCost", "float", 6.0, "W", "posture cost of a delayed release"),
    ("bMHoldOnAttackButton", "bool", True, "W", "holding the attack button delays release (MemeHold key always does)"),
    ("MemeBladeRadius", "float", 3.0, "P", "blade thickness for hit tests"),
    ("MemeClashRadius", "float", 6.0, "P", "blade-to-blade distance that clashes"),
    ("MemeProxyDelay", "float", 0.03, "P", "extra rewind for what remote players see (s)"),
    ("MemeMaxRewind", "float", 0.25, "P", "rewind cap (s)"),
    ("MemeMaxHold", "float", 0.08, "P", "cap on waiting for a defender's block in flight (s)"),
    ("MemeMaxOneWay", "float", 0.15, "P", "one-way ping cap (s)"),
    ("MemeInitiativeWindow", "float", 0.08, "P", "release gap that turns a trade into an interrupt (s)"),
    ("MemeWorldMinProgress", "float", 0.15, "P", "strike fraction before walls can stop a swing"),
    ("MemeKickActiveAt", "float", 0.3, "P", "kick fraction when it strikes"),
    ("MemeParryCone", "float", 60.0, "P", "parry half-angle from view centre (degrees)"),
    ("MemeGuardCone", "float", 75.0, "P", "guard half-angle (degrees)"),
    ("MemeShieldCone", "float", 85.0, "P", "shield guard half-angle (degrees)"),
    ("MemeGuardCostLight", "float", 12.0, "P", "guard posture cost vs light weapons"),
    ("MemeGuardCostMedium", "float", 18.0, "P", "guard posture cost vs medium weapons"),
    ("MemeGuardCostHeavy", "float", 26.0, "P", "guard posture cost vs heavy weapons"),
    ("MemeShieldGuardScale", "float", 0.6, "P", "shield guard cost scale"),
    ("MemeKickGuardCost", "float", 35.0, "P", "posture cost of a kick into guard"),
    ("MemePerfectParryAttackerCost", "float", 8.0, "P", "attacker posture lost to a perfect parry"),
    ("MemeParriedRecoil", "float", 0.6, "P", "attacker recoil after a perfect parry (s)"),
    ("MemeBlockedRecoil", "float", 0.3, "P", "attacker recoil after a guard block (s)"),
    ("MemeClashRecoil", "float", 0.45, "P", "recoil after a clash (s)"),
    ("MemeWorldRecoil", "float", 0.4, "P", "recoil after hitting a wall (s)"),
    ("MemePostureRegen", "float", 25.0, "P", "posture regen per second"),
    ("MemePostureRegenDelay", "float", 0.8, "P", "delay before regen after a loss (s)"),
    ("MemeHitStopRate", "float", 0.3, "P", "swing speed during hit stop"),
    ("MemeHitStopTime", "float", 0.06, "P", "hit stop length (s), 0 disables"),
    ("MemeLowPostureCue", "float", 30.0, "P", "posture below which POSTURE LOW shows"),
    ("MemeCueTime", "float", 0.7, "P", "cue word time on screen (s)"),
    ("MemeCueScale", "float", 1.0, "P", "cue word size"),
    ("MReactSlow", "float", 0.32, "A", "bot reaction time at skill 0 (s)"),
    ("MReactFast", "float", 0.12, "A", "bot reaction time at skill 1 (s)"),
    ("MErrSlow", "float", 0.2, "A", "bot parry timing spread at skill 0 (s)"),
    ("MErrFast", "float", 0.04, "A", "bot parry timing spread at skill 1 (s)"),
    ("MContactLead", "float", 0.15, "A", "bot guess of strike start to contact (s)"),
    ("MThreatRange", "float", 450.0, "A", "bot threat scan radius"),
    ("MLowPosture", "float", 30.0, "A", "bot low-posture threshold"),
    ("MAggression", "float", 0.6, "A", "bot aggression, -1 evasive to 1 relentless"),
    ("MAttackGapSlow", "float", 1.4, "A", "seconds between pressure attacks at skill 0"),
    ("MAttackGapFast", "float", 0.55, "A", "seconds between pressure attacks at skill 1"),
    ("MPunishSlow", "float", 0.35, "A", "chance to punish an opening at skill 0"),
    ("MPunishFast", "float", 0.95, "A", "chance to punish an opening at skill 1"),
    ("MReachSlack", "float", 30.0, "A", "extra range at which bots start an attack"),
]

HEAD = "// Generated by tools/gen_tuning.py; edit the list there, not this file.\n"


def val(t, v):
    if t == "bool":
        return "true" if v else "false"
    return repr(float(v))


def write(root, rel, text):
    path = os.path.join(root, rel)
    with open(path, "w", newline="\n") as f:
        f.write(text)
    print("wrote", rel)


def defaults(owner):
    return HEAD + "".join("\t%s=%s\n" % (n, val(t, v)) for n, t, v, o, _ in T if o == owner)


def sync(owner, func, simulated):
    lines = [HEAD, "// Copies MemeTuning into this object whenever its Version changes.\n"]
    lines.append("%sfunction %s()\n{\n\tlocal MemeTuning MT;\n\n" % ("simulated " if simulated else "", func))
    lines.append("\tif (MTuneRef == none)\n\t\tMTuneRef = class'MemeTuning'.static.Get(WorldInfo);\n\tMT = MTuneRef;\n")
    lines.append("\tif (MT == none || MT.Version == MTuneVersion)\n\t\treturn;\n")
    lines.append("\tMTuneVersion = MT.Version;\n")
    for n, t, v, o, _ in T:
        if o == owner:
            lines.append("\t%s = MT.%s;\n" % (n, n))
    lines.append("}\n")
    return "".join(lines)


def tuning_class():
    out = [HEAD]
    out.append("class MemeTuning extends ReplicationInfo;\n\n")
    out.append("// Live tunables. The server copies them from MemeTuningConfig (MemeMod.ini) and replicates them, so clients\n")
    out.append("// predict with the server's values. Admins change them with MemeTune; Version tells consumers to re-copy.\n\n")
    out.append("var int Version;\n")
    for n, t, v, o, _ in T:
        out.append("var %s %s;\n" % (t, n))
    out.append("\nreplication\n{\n\tif (bNetDirty)\n\t\tVersion")
    for n, *_ in T:
        out.append(",\n\t\t%s" % n)
    out.append(""";
}

// Server spawns the single instance on first use; clients wait for it to replicate.
static function MemeTuning Get(WorldInfo WI)
{
	local MemeTuning MT;

	if (WI == none)
		return none;
	foreach WI.DynamicActors(class'MemeTuning', MT)
		return MT;
	if (WI.NetMode != NM_Client)
	{
		MT = WI.Spawn(class'MemeTuning');
		if (MT != none)
			MT.LoadConfigValues();
	}
	return MT;
}

// Instance values differ from class defaults, so ini overrides replicate even when a client's defaults match.
function LoadConfigValues()
{
""")
    for n, *_ in T:
        out.append("\t%s = class'MemeTuningConfig'.default.%s;\n" % (n, n))
    out.append("""	Version = 1;
	bForceNetUpdate = true;
}

function bool SetByName(string N, string S)
{
	local float V;

	V = float(S);
	if (V == 0.f && !(S ~= "0" || S ~= "0.0" || S ~= "false" || S ~= "true"))
		return false;
""")
    for n, t, v, o, _ in T:
        rhs = "(V != 0.f || S ~= \"true\")" if t == "bool" else "V"
        out.append("\tif (N ~= \"%s\") { %s = %s; Version++; return true; }\n" % (n, n, rhs))
    out.append("\treturn false;\n}\n\nfunction string GetByName(string N)\n{\n")
    for n, *_ in T:
        out.append("\tif (N ~= \"%s\") return string(%s);\n" % (n, n))
    out.append("\treturn \"\";\n}\n\nfunction string NameAt(int i)\n{\n\tswitch (i)\n\t{\n")
    for i, (n, *_) in enumerate(T):
        out.append("\t\tcase %d: return \"%s\";\n" % (i, n))
    out.append("\t}\n\treturn \"\";\n}\n\nDefaultProperties\n{\n")
    out.append("`include(MemeMod/Include/MemeWeaponTuning.uci)\n")
    out.append("`include(MemeMod/Include/MemePawnTuning.uci)\n")
    out.append("`include(MemeMod/Include/MemeAIDefaults.uci)\n")
    out.append("\tbAlwaysRelevant=true\n}\n")
    return "".join(out)


def config_class():
    out = [HEAD, "class MemeTuningConfig extends Object config(Game);\n\n"]
    out.append("// Reads [MemeMod.MemeTuningConfig] from MemeMod.ini. MemeTuning copies these on the server.\n\n")
    for n, t, v, o, _ in T:
        out.append("var config %s %s;\n" % (t, n))
    out.append("\nDefaultProperties\n{\n")
    out.append("`include(MemeMod/Include/MemeWeaponTuning.uci)\n")
    out.append("`include(MemeMod/Include/MemePawnTuning.uci)\n")
    out.append("`include(MemeMod/Include/MemeAIDefaults.uci)\n}\n")
    return "".join(out)


def ini_section():
    out = ["[MemeMod.MemeTuningConfig]\n",
           "; Uncomment a line to override it. Edits apply on server restart; admins can change them live with MemeTune.\n"]
    for n, t, v, o, c in T:
        out.append("; %s\n;%s=%s\n" % (c, n, val(t, v)))
    return "".join(out)


def main():
    root = sys.argv[1]
    write(root, "Classes/MemeTuning.uc", tuning_class())
    write(root, "Classes/MemeTuningConfig.uc", config_class())
    write(root, "Include/MemeWeaponTuning.uci", defaults("W"))
    write(root, "Include/MemePawnTuning.uci", defaults("P"))
    write(root, "Include/MemeAIDefaults.uci", defaults("A"))
    write(root, "Include/MemeWeaponSync.uci", sync("W", "MemeSyncTuning", True))
    write(root, "Include/MemePawnSync.uci", sync("P", "MemeSyncTuning", True))
    write(root, "Include/MemeAISync.uci", sync("A", "MemeSyncTuning", False))

    ini_path = os.path.join(root, "DefaultMemeMod.ini")
    with open(ini_path) as f:
        ini = f.read()
    for tag in ("[MemeMod.MemeTuning]", "[MemeMod.MemeTuningConfig]"):
        cut = ini.find(tag)
        if cut >= 0:
            end = ini.find("\n[", cut + 1)
            ini = ini[:cut] + (ini[end + 1:] if end >= 0 else "")
    write(root, "DefaultMemeMod.ini", ini.rstrip("\n") + "\n\n" + ini_section())


if __name__ == "__main__":
    main()
