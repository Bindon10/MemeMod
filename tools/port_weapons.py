"""Generate MemeWeapon_* and MemeFamilyInfo_* classes from the vanilla AOC sources.

usage: python port_weapons.py <Development/Src/AOC/Classes> <MemeMod root> [UDKGame/Localization/INT/AOC.int]
Re-run after changing the mass rules; generated files are overwritten.
"""
import os, re, sys

EXCLUDE = {"AOCWeapon_Fists", "AOCWeapon_Flag", "AOCWeapon_AgathaFlag", "AOCWeapon_MasonFlag",
           "AOCWeapon_JavelinMelee", "AOCWeapon_ShortSpearMelee", "AOCWeapon_HeavyJavelinMelee"}
FAMILIES = [f + "_" + c for f in ("Agatha", "Mason") for c in ("Archer", "ManAtArms", "Vanguard", "Knight")]
# Mass is a design call, not something vanilla data states reliably (bTwoHander is often unset).
HEAVY = {"Maul", "Zweihander", "Bardiche", "Halberd", "PoleHammer", "DoubleAxe", "GrandMace", "PickAxe",
         "Greatsword", "Bearded", "WarHammer", "Dane", "PoleAxe"}
LIGHT = {"BroadDagger", "HuntingKnife", "ThrustDagger", "Dagesse", "Hatchet", "Cudgel", "Saber",
         "NorseSword", "Mace", "HolyWaterSprinkler", "Falchion"}
ARRAYS = ("NewPrimaryWeapons", "NewSecondaryWeapons", "NewTertiaryWeapons", "PrimaryWeapons", "SecondaryWeapons")


def read(path):
    with open(path, encoding="latin-1") as f:
        return f.read().replace("\r", "")


def parent_of(text):
    m = re.search(r"^\s*class\s+\w+\s+extends\s+(\w+)", text, re.M | re.I)
    return m.group(1) if m else None


def defaults(text):
    m = re.search(r"defaultproperties\s*\{(.*)\}", text, re.S | re.I)
    return m.group(1) if m else ""


def anim_len(block, arr, idx):
    m = re.search(arr + r"\(" + str(idx) + r"\)=\(.*?fAnimationLength=([0-9.]+)", block)
    return float(m.group(1)) if m else None


def lookup(cls, src, key, fn):
    while cls and cls in src:
        v = fn(defaults(src[cls]), key)
        if v is not None:
            return v
        cls = parent_of(src[cls])
    return None


def main(aoc, root, loc=None):
    src = {}
    for name in os.listdir(aoc):
        if name.endswith(".uc") and (name.startswith("AOCWeapon_") or name.startswith("AOCFamilyInfo")):
            src[name[:-3]] = read(os.path.join(aoc, name))

    def is_melee(c):
        while c in src:
            c = parent_of(src[c])
        return c == "AOCMeleeWeapon"

    ported, report, pending = {}, [], []
    for cls in sorted(src):
        if not cls.startswith("AOCWeapon_") or cls in EXCLUDE or not is_melee(cls):
            continue
        anc, skip = cls, False
        while anc in src:
            if anc in EXCLUDE:
                skip = True
            anc = parent_of(src[anc])
        if skip:
            continue
        two = lookup(cls, src, "bTwoHander", lambda b, k: (re.search(k + r"\s*=\s*(\w+)", b, re.I) or [None, None])[1])
        two = str(two).lower() == "true"
        wu = lookup(cls, src, 0, lambda b, i: anim_len(b, "WindupAnimations", i)) or 0.5
        rl = lookup(cls, src, 0, lambda b, i: anim_len(b, "ReleaseAnimations", i)) or 0.5
        short = cls[len("AOCWeapon_"):]
        mass = 2 if short in HEAVY else 0 if short in LIGHT else 1
        meme = "MemeWeapon_" + cls[len("AOCWeapon_"):]
        ported[cls] = meme
        report.append("%-34s two=%-5s windup=%.2f release=%.2f mass=%d" % (meme, two, wu, rl, mass))
        att = lookup(cls, src, "AttachmentClass", lambda b, k: (re.search(r"^\s*" + k + r"\s*=\s*class'(\w+)'", b, re.M) or [None, None])[1])
        alt = lookup(cls, src, "AlternativeMode", lambda b, k: (re.search(r"^\s*" + k + r"\s*=\s*class'(\w+)'", b, re.M) or [None, None])[1])
        pending.append((cls, meme, mass, att, alt))

    for cls, meme, mass, att, alt in pending:
        matt = "MemeWeaponAttachment_" + cls[len("AOCWeapon_"):]
        with open(os.path.join(root, "Classes", meme + ".uc"), "w", newline="\r\n") as f:
            f.write("class %s extends %s\n\timplements(IMemeWeapon);\n\n" % (meme, cls))
            f.write("`include(MemeMod/Include/MemeWeapon.uci)\n\nDefaultProperties\n{\n")
            f.write("`include(MemeMod/Include/MemeWeaponDefaults.uci)\n")
            f.write("\tMMass=%d\n" % mass)
            if att:
                f.write("\tAttachmentClass=class'%s'\n" % matt)
            if alt in ported:
                f.write("\tAlternativeMode=class'%s'\n" % ported[alt])
            f.write("}\n")
        if att:
            with open(os.path.join(root, "Classes", matt + ".uc"), "w", newline="\r\n") as f:
                f.write("class %s extends %s;\n\nDefaultProperties\n{\n\tWeaponClass=class'%s'\n}\n" % (matt, att, meme))
        else:
            report.append("WARNING no AttachmentClass for " + cls)

    for fam in FAMILIES:
        cls = "AOCFamilyInfo_" + fam
        chain, c = [], cls
        while c in src:
            chain.insert(0, c)
            c = parent_of(src[c])
        slots = {}
        for c in chain:
            for arr in ARRAYS:
                for m in re.finditer(r"^\s*" + arr + r"\((\d+)\)\s*=\s*(.*)$", defaults(src[c]), re.M):
                    w = re.search(r"class'(\w+)'", m.group(2))
                    if arr.startswith("New"):
                        w = re.search(r"CWeapon\s*=\s*class'(\w+)'", m.group(2))
                    if w:
                        slots[(arr, int(m.group(1)))] = w.group(1)
        meme = "MemeFamilyInfo_" + fam
        with open(os.path.join(root, "Classes", meme + ".uc"), "w", newline="\r\n") as f:
            f.write("class %s extends %s;\n\nDefaultProperties\n{\n" % (meme, cls))
            for (arr, i), w in sorted(slots.items()):
                if w not in ported:
                    continue
                if arr.startswith("New"):
                    f.write("\t%s(%d)=(CWeapon=class'%s')\n" % (arr, i, ported[w]))
                else:
                    f.write("\t%s(%d)=class'%s'\n" % (arr, i, ported[w]))
            f.write("}\n")

    if loc:
        with open(loc, "rb") as f:
            text = f.read().decode("utf-16")
        out = []
        for cls, meme in sorted(ported.items()):
            m = re.search(r"^\[" + cls + r"\]\r?\n(.*?)(?=^\[|\Z)", text, re.M | re.S)
            if m:
                out.append("[%s]\r\n%s" % (meme, m.group(1).strip().replace("\r\n", "\n").replace("\n", "\r\n")))
        os.makedirs(os.path.join(root, "Localization", "INT"), exist_ok=True)
        with open(os.path.join(root, "Localization", "INT", "MemeMod.int"), "wb") as f:
            f.write("\r\n\r\n".join(out).encode("utf-16"))
        report.append("localized %d weapons" % len(out))

    with open(os.path.join(root, "tools", "port_report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report))
    print("%d weapons, %d families" % (len(ported), len(FAMILIES)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
