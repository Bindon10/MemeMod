class MemeModPawn extends AOCPawn;

// Measure: posture, server-side blade sweep, rewound hit volumes and hit resolution.

const STG_HIT = 0;
const STG_KICK = 1;
const STG_BREAK = 2;
const STG_INTERRUPT = 3;
const RC_PARRIED = 0;
const RC_CLASH = 1;
const RC_WORLD = 2;
const RC_BLOCKED = 3;
const CT_HIT = 0;
const CT_BLOCKED = 1;
const HIST = 32;

struct MemeCapDef
{
	var name BoneA;
	var name BoneB;
	var float Radius;
	var name HitBone;
};

struct MemeCap
{
	var vector A;
	var vector B;
	var float R;
	var name Bone;
	var int Owner;
};

struct MemeHold
{
	var MemeModPawn Attacker;
	var name Bone;
	var vector HitP;
	var vector GuardP;
	var float Start;
	var float Expire;
};

// Tunables
var array<MemeCapDef> MemeCapDefs;
var float MemeBladeRadius;
var float MemeClashRadius;
var float MemeProxyDelay;
var float MemeMaxRewind;
var float MemeMaxHold;
var float MemeMaxOneWay;
var float MemeInitiativeWindow;
var float MemeWorldMinProgress;
var float MemeKickActiveAt;
var float MemeParryCone;
var float MemeGuardCone;
var float MemeShieldCone;
var float MemeGuardCostLight;
var float MemeGuardCostMedium;
var float MemeGuardCostHeavy;
var float MemeShieldGuardScale;
var float MemeKickGuardCost;
var float MemePerfectParryAttackerCost;
var float MemeParriedRecoil;
var float MemeBlockedRecoil;
var float MemeClashRecoil;
var float MemeWorldRecoil;
var float MemePostureRegen;
var float MemePostureRegenDelay;
var float MemeHitStopRate;
var float MemeHitStopTime;
var float MemeLowPostureCue;
var float MemeCueTime;
var float MemeCueScale;
var int   MTuneVersion;
var MemeTuning MTuneRef;
var float MemeNextTuneTry;
var bool  bMemeHoldKey;
var bool  bMemeFireDown0;
var bool  bMemeFireDown1;
var bool  bMemeDebugDraw;
var float MemeNextCapDraw;
var float MemeLastRewind;

// Server runtime
var float MemeHistT[HIST];
var vector MemeHistL[HIST];
var rotator MemeHistR[HIST];
var int MemeHistHead;
var int MemeHistCount;
var vector MemePrevA;
var vector MemePrevB;
var bool bMemeHavePrev;
var array<AOCPawn> MemeStruck;
var array<MemeHold> MemeHolds;
var bool bMemeKickDone;
var int MemeWorldStreak;
var Actor MemeWorldDamaged;
var float MemeLastPostureLoss;

// Hit stop (all clients)
var repnotify byte MemeHitStopCount;
var AnimNodeSequence MemeStopSeq;
var AnimNodeSequence MemeStopSeqOwner;
var float MemeStopRate;
var float MemeStopRateOwner;

// Perfect-parry sparks (all clients) and per-player cue toggle (server)
var repnotify byte MemeParryFxCount;
var vector MemeParryFxLoc;
var bool bMemeNoCues;
var string MemeCueText;
var float MemeCueUntil;
var byte MemeCueTone;

replication
{
	if (bNetDirty)
		MemeHitStopCount, MemeParryFxCount, MemeParryFxLoc;
}

`include(MemeMod/Include/MemePawnSync.uci)

// ---------------------------------------------------------------- basics

simulated function float MemeOneWay()
{
	if (bIsBot || PlayerReplicationInfo == none)
		return 0.f;
	return FClamp(PlayerReplicationInfo.ExactPing * 0.5f, 0.f, MemeMaxOneWay);
}

simulated function float MemeRTT()
{
	return MemeOneWay() * 2.f;
}

simulated event ReplicatedEvent(name VarName)
{
	// A pawn just becoming relevant replicates old counters; don't replay their effects.
	if (VarName == 'MemeHitStopCount' || VarName == 'MemeParryFxCount')
	{
		if (WorldInfo.TimeSeconds - CreationTime < 0.5f)
			return;
		if (VarName == 'MemeHitStopCount')
			MemeDoHitStop();
		else
			MemeSpawnParryFx();
	}
	else
		super.ReplicatedEvent(VarName);
}

simulated event Tick(float DeltaTime)
{
	local IMemeWeapon W;

	super.Tick(DeltaTime);
	if (WorldInfo.TimeSeconds >= MemeNextTuneTry)
	{
		MemeNextTuneTry = WorldInfo.TimeSeconds + 0.5f;
		MemeSyncTuning();
	}
	if (Role < ROLE_Authority)
		return;

	MemeRecordSnap();
	if (MemeHolds.Length > 0)
		MemeProcessHolds();

	W = IMemeWeapon(Weapon);
	if (W != none && W.MemeIsStriking() && Health > 0)
		MemeSweep(W);
}

simulated function bool GetSwingTurnCaps(out float YawCap, out float PitchCap)
{
	local IMemeWeapon W;

	W = IMemeWeapon(Weapon);
	return W != none && W.MemeGetTurnCaps(YawCap, PitchCap);
}

// Melee claims from clients are ignored; the server sweeps every Meme weapon itself.
reliable server function AttackOtherPawn(HitInfo Info, string DamageString, optional bool bCheckParryOnly = false, optional bool bBoxParrySuccess, optional bool bHitShield = false, optional SwingTypeImpactSound LastHit = ESWINGSOUND_Slash, optional bool bQuickKick = false)
{
	if (IMemeWeapon(Weapon) != none && Info.DamageType != none && !Info.DamageType.default.bIsProjectile)
		return;
	super.AttackOtherPawn(Info, DamageString, bCheckParryOnly, bBoxParrySuccess, bHitShield, LastHit, bQuickKick);
}

// ---------------------------------------------------------------- posture

simulated function bool ConsumeStamina(float Amount)
{
	if (Amount > 0.f)
		MemeLastPostureLoss = WorldInfo.TimeSeconds;
	return super.ConsumeStamina(Amount);
}

simulated function RegenStamina()
{
	local IMemeWeapon W;

	if (Role < ROLE_Authority || Weapon == none || Stamina >= MaxStamina)
		return;
	W = IMemeWeapon(Weapon);
	if (W != none && (W.MemeIsGuarding() || W.MemeIsWindingUp() || W.MemeIsStriking() || W.MemeIsStaggered()))
		return;
	if (WorldInfo.TimeSeconds - MemeLastPostureLoss < MemePostureRegenDelay)
		return;
	Stamina = FMin(MaxStamina, Stamina + MemePostureRegen / FMax(StaminaPerSecond, 1.f));
	ReplicatedStamina = Clamp(Stamina / MaxStamina * 255, 0, 255);
}

// ---------------------------------------------------------------- history and hit volumes

function MemeRecordSnap()
{
	MemeHistHead = (MemeHistHead + 1) % HIST;
	MemeHistT[MemeHistHead] = WorldInfo.TimeSeconds;
	MemeHistL[MemeHistHead] = Location;
	MemeHistR[MemeHistHead] = Rotation;
	if (MemeHistCount < HIST)
		MemeHistCount++;
}

function MemeRewound(float T, out vector L, out rotator R)
{
	local int i, Idx, Newer;
	local float Alpha;

	L = Location;
	R = Rotation;
	if (MemeHistCount == 0 || T >= MemeHistT[MemeHistHead])
		return;

	Newer = MemeHistHead;
	for (i = 1; i < MemeHistCount; i++)
	{
		Idx = (MemeHistHead - i + HIST) % HIST;
		if (MemeHistT[Idx] <= T)
		{
			Alpha = (T - MemeHistT[Idx]) / FMax(MemeHistT[Newer] - MemeHistT[Idx], 0.001f);
			L = MemeHistL[Idx] + (MemeHistL[Newer] - MemeHistL[Idx]) * Alpha;
			R = RLerp(MemeHistR[Idx], MemeHistR[Newer], Alpha, true);
			return;
		}
		Newer = Idx;
	}
	L = MemeHistL[Newer];
	R = MemeHistR[Newer];
}

// Current pose, carried to where this pawn stood at time T.
function MemeAppendCaps(float T, int OwnerIdx, out array<MemeCap> Caps)
{
	local int i;
	local vector L, BA, BB;
	local rotator R, DeltaYaw;
	local MemeCap C;

	MemeRewound(T, L, R);
	DeltaYaw.Yaw = R.Yaw - Rotation.Yaw;

	for (i = 0; i < MemeCapDefs.Length; i++)
	{
		if (Mesh.MatchRefBone(MemeCapDefs[i].BoneA) == INDEX_NONE || Mesh.MatchRefBone(MemeCapDefs[i].BoneB) == INDEX_NONE)
			continue;
		BA = Mesh.GetBoneLocation(MemeCapDefs[i].BoneA) - Location;
		BB = Mesh.GetBoneLocation(MemeCapDefs[i].BoneB) - Location;
		C.A = L + (BA >> DeltaYaw);
		C.B = L + (BB >> DeltaYaw);
		C.R = MemeCapDefs[i].Radius;
		C.Bone = MemeCapDefs[i].HitBone;
		C.Owner = OwnerIdx;
		Caps.AddItem(C);
	}
}

static final function float MemeSegDistSq(vector P1, vector Q1, vector P2, vector Q2, out vector C1, out vector C2)
{
	local vector D1, D2, R;
	local float A, E, F, C, B, Denom, S, T;

	D1 = Q1 - P1;
	D2 = Q2 - P2;
	R = P1 - P2;
	A = D1 dot D1;
	E = D2 dot D2;
	F = D2 dot R;
	S = 0.f;
	T = 0.f;
	if (A <= 0.0001f && E <= 0.0001f)
	{
		C1 = P1;
		C2 = P2;
		return VSizeSq(C1 - C2);
	}
	if (A <= 0.0001f)
	{
		T = FClamp(F / E, 0.f, 1.f);
	}
	else
	{
		C = D1 dot R;
		if (E <= 0.0001f)
		{
			S = FClamp(-C / A, 0.f, 1.f);
		}
		else
		{
			B = D1 dot D2;
			Denom = A * E - B * B;
			if (Denom != 0.f)
				S = FClamp((B * F - C * E) / Denom, 0.f, 1.f);
			T = (B * S + F) / E;
			if (T < 0.f)
			{
				T = 0.f;
				S = FClamp(-C / A, 0.f, 1.f);
			}
			else if (T > 1.f)
			{
				T = 1.f;
				S = FClamp((B - C) / A, 0.f, 1.f);
			}
		}
	}
	C1 = P1 + D1 * S;
	C2 = P2 + D2 * T;
	return VSizeSq(C1 - C2);
}

// ---------------------------------------------------------------- sweep

function bool MemeGetBlade(out vector A, out vector B)
{
	local AOCWeaponAttachment Att;
	local name SB, SE;
	local int N;

	Att = AOCWeaponAttachment(CurrentWeaponAttachment);
	if (Att == none || Att.Mesh == none)
		return false;
	N = Max(Att.WeaponNumTracers, 1);
	Att.GetTracerSocketNames(SB, SE, 0);
	if (!Att.Mesh.GetSocketWorldLocationAndRotation(SB, A))
		return false;
	Att.GetTracerSocketNames(SB, SE, N - 1);
	if (!Att.Mesh.GetSocketWorldLocationAndRotation(SE, B))
		return false;
	return VSizeSq(B - A) > 1.f;
}

function vector MemePivot()
{
	if (Mesh.MatchRefBone('b_r_shoulder') != INDEX_NONE)
		return Mesh.GetBoneLocation('b_r_shoulder');
	return Location + vect(0,0,30);
}

static final function vector MemeArcLerp(vector P0, vector P1, vector Pivot, float T)
{
	local vector V0, V1, Mid;

	V0 = P0 - Pivot;
	V1 = P1 - Pivot;
	Mid = V0 * (1.f - T) + V1 * T;
	if (VSizeSq(Mid) < 1.f)
		return P0 + (P1 - P0) * T;
	return Pivot + Normal(Mid) * Lerp(VSize(V0), VSize(V1), T);
}

// Kind: 0 sweep, 1 capsule, 2 contact, 3 clear. Remote owners get the lines by RPC.
function MemeDebugLine(vector A, vector B, byte Kind, optional float Radius)
{
	if (IsLocallyControlled())
		MemeDrawDebug(A, B, Kind, Radius);
	else if (Kind == 3)
		ClientMemeDebugClear();
	else
		ClientMemeDebugLine(A, B, Kind, Radius);
}

reliable client function ClientMemeDebugClear()
{
	FlushPersistentDebugLines();
}

unreliable client function ClientMemeDebugLine(vector A, vector B, byte Kind, float Radius)
{
	MemeDrawDebug(A, B, Kind, Radius);
}

// Capsules are drawn as surfaces; their centre lines sit inside the mesh and get hidden.
simulated function MemeDrawDebug(vector A, vector B, byte Kind, float Radius)
{
	if (Kind == 0)
		DrawDebugLine(A, B, 255, 64, 0, true);
	else if (Kind == 1 && VSizeSq(B - A) < 1.f)
		DrawDebugSphere(A, Radius, 8, 0, 200, 255, true);
	else if (Kind == 1)
		DrawDebugCylinder(A, B, Radius, 8, 0, 200, 255, true);
	else if (Kind == 2)
		DrawDebugSphere(A, 4.f, 6, 255, 0, 0, true);
	else
		FlushPersistentDebugLines();
}

function string MemeName(Pawn P)
{
	if (P == none)
		return "world";
	if (P.PlayerReplicationInfo != none)
		return P.PlayerReplicationInfo.PlayerName;
	return string(P.Name);
}

static function string MemeMs(float Seconds)
{
	return int(Seconds * 1000.f) $ "ms";
}

// MemeDebug combat log: both sides see what the server decided and why.
function MemeLog(Pawn Other, string Msg)
{
	Msg = "[Measure]" @ MemeName(self) @ "->" @ MemeName(Other) $ ":" @ Msg;
	if (bMemeDebugDraw && PlayerController(Controller) != none)
		PlayerController(Controller).ClientMessage(Msg);
	if (MemeModPawn(Other) != none && MemeModPawn(Other).bMemeDebugDraw && PlayerController(Other.Controller) != none)
		PlayerController(Other.Controller).ClientMessage(Msg);
}

// Owning client only: whether Fire (0) / AltFire (1) is physically held. Set by the player controller.
simulated function bool MemeFireDown(byte FireModeNum)
{
	if (FireModeNum == 0)
		return bMemeFireDown0;
	if (FireModeNum == 1)
		return bMemeFireDown1;
	return false;
}

// Short word under the crosshair for this pawn's player. Tone 0 good, 1 bad. MemeCues turns them off.
function MemeCue(string Msg, optional byte Tone)
{
	if (!bMemeNoCues && IsHumanControlled())
		ClientMemeCue(Msg, Tone);
}

reliable client function ClientMemeCue(string Msg, byte Tone)
{
	MemeCueText = Msg;
	MemeCueTone = Tone;
	MemeCueUntil = WorldInfo.TimeSeconds + MemeCueTime;
}

static function MemeCueOn(Pawn P, string Msg, optional byte Tone)
{
	if (MemeModPawn(P) != none)
		MemeModPawn(P).MemeCue(Msg, Tone);
}

simulated function DrawHUD(HUD H)
{
	local float XL, YL, A;

	super.DrawHUD(H);
	if (MemeCueText == "" || WorldInfo.TimeSeconds >= MemeCueUntil || H == none || H.Canvas == none)
		return;
	A = FClamp((MemeCueUntil - WorldInfo.TimeSeconds) / 0.25f, 0.f, 1.f);
	H.Canvas.Font = class'Engine'.static.GetMediumFont();
	H.Canvas.TextSize(MemeCueText, XL, YL, MemeCueScale, MemeCueScale);
	H.Canvas.SetPos((H.Canvas.ClipX - XL) * 0.5f, H.Canvas.ClipY * 0.5f + YL * 2.f);
	if (MemeCueTone == 1)
		H.Canvas.SetDrawColor(255, 70, 50, byte(255.f * A));
	else
		H.Canvas.SetDrawColor(255, 210, 90, byte(255.f * A));
	H.Canvas.DrawText(MemeCueText, false, MemeCueScale, MemeCueScale);
}

function MemeParryFx(vector Loc)
{
	MemeParryFxLoc = Loc;
	MemeParryFxCount++;
	if (WorldInfo.NetMode != NM_DedicatedServer)
		MemeSpawnParryFx();
}

simulated function MemeSpawnParryFx()
{
	if (AOCWeaponAttachment(CurrentWeaponAttachment) != none && WorldInfo.MyEmitterPool != none)
		WorldInfo.MyEmitterPool.SpawnEmitter(AOCWeaponAttachment(CurrentWeaponAttachment).ParryPS, MemeParryFxLoc);
}

function MemeBeginStrike()
{
	bMemeHavePrev = false;
	bMemeKickDone = false;
	MemeWorldStreak = 0;
	MemeWorldDamaged = none;
	MemeStruck.Length = 0;
	if (bMemeDebugDraw)
		MemeDebugLine(vect(0,0,0), vect(0,0,0), 3);
}

function MemeEndStrike()
{
	bMemeHavePrev = false;
}

function MemeSweep(IMemeWeapon W)
{
	local vector A, B, SA, SB, Pivot, C1, C2, V0, V1;
	local float RewindTo, Ang, D, Reach;
	local int Steps, k, i, n;
	local AOCPawn P;
	local array<AOCPawn> Defs;
	local array<MemeCap> Caps;
	local array<float> BestD;
	local array<int> BestCap;
	local array<vector> BestPoint;
	local bool bStopped;

	if (!MemeGetBlade(A, B))
		return;
	if (!bMemeHavePrev)
	{
		MemePrevA = A;
		MemePrevB = B;
		bMemeHavePrev = true;
	}

	if (W.MemeAttackType() == Attack_Shove)
	{
		if (!bMemeKickDone && W.MemeStrikeProgress() >= MemeKickActiveAt)
		{
			bMemeKickDone = true;
			MemeDoKick(W);
		}
		return;
	}

	Pivot = MemePivot();
	Reach = FMax(VSize(B - Pivot), VSize(MemePrevB - Pivot)) + 60.f;
	// Only remote players saw the world late; local players and bots see it live.
	RewindTo = WorldInfo.TimeSeconds;
	if (!IsLocallyControlled())
		RewindTo -= FMin(MemeRTT() + MemeProxyDelay, MemeMaxRewind);
	MemeLastRewind = WorldInfo.TimeSeconds - RewindTo;

	foreach WorldInfo.AllPawns(class'AOCPawn', P, Location, Reach + 100.f)
	{
		if (P == self || P.Health <= 0 || P.bPlayedDeath || MemeStruck.Find(P) != INDEX_NONE)
			continue;
		n = Defs.Length;
		Defs.AddItem(P);
		BestD.AddItem(1000000.f);
		BestCap.AddItem(-1);
		BestPoint.AddItem(P.Location);
		if (MemeModPawn(P) != none)
			MemeModPawn(P).MemeAppendCaps(RewindTo, n, Caps);
		else
			MemeAppendCylinder(P, n, Caps);
	}

	V0 = Normal(MemePrevB - Pivot);
	V1 = Normal(B - Pivot);
	Ang = Acos(FClamp(V0 dot V1, -1.f, 1.f));
	Steps = Clamp(int(Ang / 0.26f) + 1, 1, 6);

	for (k = 1; k <= Steps && !bStopped; k++)
	{
		SA = MemeArcLerp(MemePrevA, A, Pivot, float(k) / float(Steps));
		SB = MemeArcLerp(MemePrevB, B, Pivot, float(k) / float(Steps));
		if (bMemeDebugDraw)
			MemeDebugLine(SA, SB, 0);

		if (MemeTestClash(W, SA, SB) || (W.MemeStrikeProgress() >= MemeWorldMinProgress && MemeTestWorld(W, SA, SB)))
		{
			bStopped = true;
			break;
		}

		for (i = 0; i < Caps.Length; i++)
		{
			D = MemeSegDistSq(SA, SB, Caps[i].A, Caps[i].B, C1, C2);
			if (D < (Caps[i].R + MemeBladeRadius) * (Caps[i].R + MemeBladeRadius) && D < BestD[Caps[i].Owner])
			{
				BestD[Caps[i].Owner] = D;
				BestCap[Caps[i].Owner] = i;
				BestPoint[Caps[i].Owner] = C2;
			}
		}
		for (n = 0; n < Defs.Length && !bStopped; n++)
		{
			if (BestCap[n] < 0 || MemeStruck.Find(Defs[n]) != INDEX_NONE)
				continue;
			if (bMemeDebugDraw)
				MemeDebugLine(BestPoint[n], BestPoint[n], 2);
			bStopped = MemeResolveContact(W, Defs[n], Caps[BestCap[n]].Bone, BestPoint[n], (SA + SB) * 0.5f);
		}
	}

	if (bMemeDebugDraw && WorldInfo.TimeSeconds >= MemeNextCapDraw)
	{
		MemeNextCapDraw = WorldInfo.TimeSeconds + 0.1f;
		for (i = 0; i < Caps.Length; i++)
			MemeDebugLine(Caps[i].A, Caps[i].B, 1, Caps[i].R + MemeBladeRadius);
	}

	if (!bStopped)
	{
		MemePrevA = A;
		MemePrevB = B;
	}
}

function MemeAppendCylinder(AOCPawn P, int OwnerIdx, out array<MemeCap> Caps)
{
	local MemeCap C;

	C.A = P.Location - vect(0,0,1) * P.CylinderComponent.CollisionHeight * 0.8f;
	C.B = P.Location + vect(0,0,1) * P.CylinderComponent.CollisionHeight * 0.8f;
	C.R = P.CylinderComponent.CollisionRadius * 0.6f;
	C.Bone = 'b_spine_C';
	C.Owner = OwnerIdx;
	Caps.AddItem(C);
}

function bool MemeTestClash(IMemeWeapon W, vector SA, vector SB)
{
	local MemeModPawn O;
	local IMemeWeapon OW;
	local vector C1, C2;

	foreach WorldInfo.AllPawns(class'MemeModPawn', O, Location, 400.f)
	{
		if (O == self || !O.bMemeHavePrev || O.Health <= 0)
			continue;
		OW = IMemeWeapon(O.Weapon);
		if (OW == none || !OW.MemeIsStriking())
			continue;
		if (MemeSegDistSq(SA, SB, O.MemePrevA, O.MemePrevB, C1, C2) < MemeClashRadius * MemeClashRadius)
		{
			AOCWeaponAttachment(CurrentWeaponAttachment).PlayParriedSound();
			AOCWeaponAttachment(O.CurrentWeaponAttachment).PlayParriedSound();
			MemeLog(O, "CLASH, both recoil");
			MemeCue("CLASH");
			O.MemeCue("CLASH");
			W.MemeServerRecoil(RC_CLASH, MemeClashRecoil, false);
			OW.MemeServerRecoil(RC_CLASH, MemeClashRecoil, false);
			return true;
		}
	}
	return false;
}

function bool MemeTestWorld(IMemeWeapon W, vector SA, vector SB)
{
	local Actor HitA;
	local vector HL, HN;
	local TraceHitInfo TI;
	local AOCWeaponAttachment Att;
	local byte Atk;

	HitA = Trace(HL, HN, SB, (SA + SB) * 0.5f, true,, TI);
	if (HitA == none || Pawn(HitA) != none || AOCWeaponAttachment(HitA) != none || Projectile(HitA) != none || HitA == self)
	{
		MemeWorldStreak = 0;
		return false;
	}
	MemeWorldStreak++;
	if (MemeWorldStreak < 2)
		return false;

	Att = AOCWeaponAttachment(CurrentWeaponAttachment);
	Atk = W.MemeAttackType();
	if (!HitA.bWorldGeometry && HitA != MemeWorldDamaged)
	{
		MemeWorldDamaged = HitA;
		Server_ForceTakeDamage(Att.AttackTypeInfo[Atk].fBaseDamage, HL, HN, vect(0,0,0), HitA, Att.AttackTypeInfo[Atk].cDamageType);
	}
	Att.LastSwingType = MemeSwingSound(Atk);
	Att.PlayHitWorldSound(HitA, TI);
	MemeLog(none, "WALL (" $ HitA.Name $ "), recoil");
	W.MemeServerRecoil(RC_WORLD, MemeWorldRecoil, false);
	return true;
}

static function SwingTypeImpactSound MemeSwingSound(byte Atk)
{
	if (Atk == Attack_Overhead)
		return ESWINGSOUND_Overhead;
	if (Atk == Attack_Stab)
		return ESWINGSOUND_Stab;
	if (Atk == Attack_Sprint)
		return ESWINGSOUND_Sprint;
	if (Atk == Attack_Shove)
		return ESWINGSOUND_Shove;
	return ESWINGSOUND_Slash;
}

// ---------------------------------------------------------------- resolution

function rotator MemeViewOf(AOCPawn P)
{
	if (P.Controller != none)
		return P.Controller.Rotation;
	return P.GetBaseAimRotation();
}

// Defence is spatial: the incoming blade must be inside the defender's view cone.
function bool MemeGuardCovers(AOCPawn P, vector From)
{
	local IMemeWeapon DW;
	local float MinCos;
	local vector Eye;

	DW = IMemeWeapon(P.Weapon);
	if (DW != none)
	{
		if (!DW.MemeIsGuarding())
			return false;
		if (DW.MemeInParryWindow())
			MinCos = Cos(MemeParryCone * DegToRad);
		else if (DW.MemeIsShieldGuard())
			MinCos = Cos(MemeShieldCone * DegToRad);
		else
			MinCos = Cos(MemeGuardCone * DegToRad);
	}
	else if (P.StateVariables.bIsParrying || P.StateVariables.bIsActiveShielding)
	{
		MinCos = Cos(MemeGuardCone * DegToRad);
	}
	else
	{
		return false;
	}
	Eye = P.Location + vect(0,0,1) * P.BaseEyeHeight;
	return (Normal(From - Eye) dot vector(MemeViewOf(P))) >= MinCos;
}

function bool MemeResolveContact(IMemeWeapon W, AOCPawn P, name Bone, vector HitP, vector BladeMid)
{
	local IMemeWeapon DW;
	local MemeModPawn MP;

	MemeStruck.AddItem(P);
	DW = IMemeWeapon(P.Weapon);

	if (MemeGuardCovers(P, BladeMid))
		return MemeApplyBlock(W, P, DW != none && DW.MemeInParryWindow(), BladeMid);

	MP = MemeModPawn(P);
	if (MP != none && DW != none && !DW.MemeIsStaggered() && !DW.MemeIsStriking() && MP.MemeOneWay() > 0.015f)
	{
		MP.MemeQueueHold(self, Bone, HitP, BladeMid);
		return false;
	}
	MemeApplyHit(W, P, Bone, HitP);
	return false;
}

// Decide once: a parry still in flight from the defender gets a short chance to arrive.
function MemeQueueHold(MemeModPawn Attacker, name Bone, vector HitP, vector GuardP)
{
	local MemeHold H;

	H.Attacker = Attacker;
	H.Bone = Bone;
	H.HitP = HitP;
	H.GuardP = GuardP;
	H.Start = WorldInfo.TimeSeconds;
	H.Expire = WorldInfo.TimeSeconds + FMin(MemeOneWay(), MemeMaxHold);
	MemeHolds.AddItem(H);
}

function MemeProcessHolds()
{
	local int i;
	local MemeHold H;
	local IMemeWeapon AW, DW;

	for (i = MemeHolds.Length - 1; i >= 0; i--)
	{
		H = MemeHolds[i];
		AW = none;
		if (H.Attacker != none)
			AW = IMemeWeapon(H.Attacker.Weapon);
		if (AW == none || H.Attacker.bDeleteMe || H.Attacker.Health <= 0 || Health <= 0)
		{
			MemeHolds.Remove(i, 1);
			continue;
		}
		if (H.Attacker.MemeGuardCovers(self, H.GuardP))
		{
			MemeHolds.Remove(i, 1);
			H.Attacker.MemeLog(self, "held" @ MemeMs(WorldInfo.TimeSeconds - H.Start) $ ", block arrived in time");
			DW = IMemeWeapon(Weapon);
			H.Attacker.MemeApplyBlock(AW, self, DW != none && DW.MemeInParryWindow(), H.GuardP);
		}
		else if (WorldInfo.TimeSeconds >= H.Expire)
		{
			MemeHolds.Remove(i, 1);
			H.Attacker.MemeLog(self, "held" @ MemeMs(WorldInfo.TimeSeconds - H.Start) $ ", no block");
			H.Attacker.MemeApplyHit(AW, self, H.Bone, H.HitP);
		}
	}
}

function MemeGuardRaised()
{
	if (MemeHolds.Length > 0)
		MemeProcessHolds();
}

// Guard-side cues after posture was spent: break, or crossing into low posture.
function MemeCueGuard(AOCPawn P, float Cost)
{
	if (P.Stamina <= 0.f)
	{
		MemeCue("GUARD BREAK");
		MemeCueOn(P, "GUARD BROKEN", 1);
	}
	else if (P.Stamina < MemeLowPostureCue && P.Stamina + Cost >= MemeLowPostureCue)
	{
		MemeCueOn(P, "POSTURE LOW", 1);
	}
}

function bool MemeApplyBlock(IMemeWeapon W, AOCPawn P, bool bPerfect, vector FxLoc)
{
	local IMemeWeapon DW;
	local byte Atk, Dir;
	local float Cost;
	local IAOCAIListener AIList;

	DW = IMemeWeapon(P.Weapon);
	Atk = W.MemeAttackType();
	if (Atk == Attack_Slash && W.MemeAttackIsAlt())
		Dir = 1;
	else if (Atk == Attack_Slash)
		Dir = 0;
	else if (Atk == Attack_Stab)
		Dir = 3;
	else
		Dir = 2;

	if (bPerfect)
	{
		ConsumeStamina(MemePerfectParryAttackerCost);
		AOCWeaponAttachment(CurrentWeaponAttachment).PlayParriedSound();
		AOCWeaponAttachment(P.CurrentWeaponAttachment).PlayParrySound(false);
		MemeLog(P, "PARRIED (perfect), attacker posture" @ int(Stamina));
		MemeCue("PARRIED", 1);
		MemeCueOn(P, "PARRY");
		if (MemeModPawn(P) != none)
			MemeModPawn(P).MemeParryFx(FxLoc);
		if (P.IsHumanControlled())
			P.PlayerHUDStartCombo();
		if (DW != none)
			DW.MemeServerBlocked(true, Dir);
		W.MemeServerRecoil(RC_PARRIED, MemeParriedRecoil, false);
	}
	else
	{
		Cost = W.MemeMassClass() == 0 ? MemeGuardCostLight : (W.MemeMassClass() == 1 ? MemeGuardCostMedium : MemeGuardCostHeavy);
		if (DW != none && DW.MemeIsShieldGuard())
			Cost *= MemeShieldGuardScale;
		P.ConsumeStamina(Cost);
		AOCWeaponAttachment(P.CurrentWeaponAttachment).PlayParrySound(DW != none && DW.MemeIsShieldGuard());
		MemeLog(P, (P.Stamina <= 0.f ? "GUARD BREAK" : "BLOCKED") $ ", -" $ int(Cost) @ "posture," @ int(FMax(P.Stamina, 0.f)) @ "left");
		MemeCueGuard(P, Cost);
		if (P.Stamina <= 0.f)
		{
			if (DW != none)
				DW.MemeServerStagger(STG_BREAK, Location);
			else
				AOCWeapon(P.Weapon).ActivateFlinch(true, P.GetHitDirection(Location), true, true, false);
		}
		else if (DW != none)
		{
			DW.MemeServerBlocked(false, Dir);
		}
		else if (AOCWeapon(P.Weapon) != none)
		{
			AOCWeapon(P.Weapon).NotifySuccessfulParry(EAttack(Atk), Dir);
		}
		W.MemeServerContact(CT_BLOCKED);
		W.MemeServerRecoil(RC_BLOCKED, MemeBlockedRecoil, true);
	}

	foreach P.AICombatInterests(AIList)
		AIList.NotifyPawnSuccessBlock(P, self);
	return true;
}

function MemeApplyHit(IMemeWeapon W, AOCPawn P, name Bone, vector HitP)
{
	local IMemeWeapon DW;
	local bool bStagger;
	local byte Kind, Atk;
	local HitInfo Info;
	local AOCWeaponAttachment Att;
	local string Why;

	Att = AOCWeaponAttachment(CurrentWeaponAttachment);
	if (Att == none || P == none || P.Health <= 0)
		return;
	Atk = W.MemeAttackType();
	DW = IMemeWeapon(P.Weapon);

	bStagger = true;
	Kind = STG_HIT;
	Why = "stagger";
	if (DW != none)
	{
		if (DW.MemeIsStriking())
		{
			if (!DW.MemeIsHyperArmored() && DW.MemeStrikeStart() > W.MemeStrikeStart() + MemeInitiativeWindow)
			{
				Kind = STG_INTERRUPT;
				Why = "INTERRUPT, they released" @ MemeMs(DW.MemeStrikeStart() - W.MemeStrikeStart()) @ "later";
			}
			else
			{
				bStagger = false;
				Why = DW.MemeIsHyperArmored() ? "hyper-armour, no stagger" : ("TRADE, released" @ MemeMs(Abs(DW.MemeStrikeStart() - W.MemeStrikeStart())) @ "apart");
			}
		}
		else if (DW.MemeIsStaggered())
		{
			bStagger = false;
			Why = "already staggered, damage only";
		}
		else if (DW.MemeIsGuarding())
		{
			Why = "outside guard cone, stagger";
		}
	}
	MemeLog(P, "HIT" @ Bone $ "," @ Why $ ", rewind" @ MemeMs(MemeLastRewind));
	if (Kind == STG_INTERRUPT)
	{
		MemeCue("INTERRUPT");
		MemeCueOn(P, "INTERRUPTED", 1);
	}

	Info.HitActor = P;
	Info.Instigator = self;
	Info.PRI = PlayerReplicationInfo;
	Info.DamageType = Att.AttackTypeInfo[Atk].cDamageType;
	Info.HitDamage = Att.AttackTypeInfo[Atk].fBaseDamage;
	Info.HitLocation = HitP;
	Info.HitForce = Att.AttackTypeInfo[Atk].fForce * Normal(P.Location - Location);
	Info.HitNormal = Normal(Location - HitP);
	Info.HitComp = P.Mesh;
	Info.AttackType = EAttack(Atk);
	Info.BoneName = Bone;
	if (Weapon.Class == PrimaryWeapon || Weapon.Class == AlternatePrimaryWeapon)
		Info.UsedWeapon = 0;
	else if (Weapon.Class == SecondaryWeapon)
		Info.UsedWeapon = 1;
	else
		Info.UsedWeapon = 3;

	Att.LastSwingType = MemeSwingSound(Atk);
	super.AttackOtherPawn(Info, AOCWeapon(Weapon).WeaponFontSymbol, false, false, false, Att.LastSwingType, false);

	if (bStagger && P != none && P.Health > 0 && IMemeWeapon(P.Weapon) != none)
		IMemeWeapon(P.Weapon).MemeServerStagger(Kind, Location);

	W.MemeServerContact(CT_HIT);
	MemeHitStopCount++;
	if (WorldInfo.NetMode != NM_DedicatedServer)
		MemeDoHitStop();
}

function MemeDoKick(IMemeWeapon W)
{
	local AOCPawn T;
	local AOCWeaponAttachment Att;
	local vector Center;
	local HitInfo Info;
	local IMemeWeapon DW;

	Att = AOCWeaponAttachment(CurrentWeaponAttachment);
	if (Att == none)
		return;
	Center = Location + Vector(Rotation) * Att.KickOffset.X + vect(0,0,1) * Att.KickOffset.Z;

	foreach OverlappingActors(class'AOCPawn', T, Att.KickSize, Center, true)
	{
		if (T == self || T.Health <= 0 || MemeStruck.Find(T) != INDEX_NONE)
			continue;
		MemeStruck.AddItem(T);
		DW = IMemeWeapon(T.Weapon);

		if (MemeGuardCovers(T, Location + vect(0,0,1) * BaseEyeHeight * 0.5f))
		{
			T.ConsumeStamina(MemeKickGuardCost);
			MemeLog(T, "KICK into guard, -" $ int(MemeKickGuardCost) @ "posture," @ int(FMax(T.Stamina, 0.f)) @ "left");
			MemeCueGuard(T, MemeKickGuardCost);
			if (DW != none && T.Stamina <= 0.f)
				DW.MemeServerStagger(STG_BREAK, Location);
			else if (DW != none)
				DW.MemeServerStagger(STG_HIT, Location);
			W.MemeServerContact(CT_BLOCKED);
			continue;
		}

		MemeLog(T, "KICK hit, stagger");
		Info.HitActor = T;
		Info.Instigator = self;
		Info.PRI = PlayerReplicationInfo;
		Info.DamageType = Att.AttackTypeInfo[Attack_Shove].cDamageType;
		Info.HitDamage = Att.AttackTypeInfo[Attack_Shove].fBaseDamage;
		Info.HitLocation = T.Location;
		Info.HitForce = Att.AttackTypeInfo[Attack_Shove].fForce * Normal(T.Location - Location);
		Info.HitNormal = Normal(Location - T.Location);
		Info.HitComp = T.Mesh;
		Info.AttackType = Attack_Shove;
		Info.BoneName = 'b_spine_C';
		Info.UsedWeapon = 3;
		Att.LastSwingType = ESWINGSOUND_Shove;
		super.AttackOtherPawn(Info, AOCWeapon(Weapon).WeaponFontSymbol, false, false, false, ESWINGSOUND_Shove, false);
		if (T != none && T.Health > 0 && IMemeWeapon(T.Weapon) != none)
			IMemeWeapon(T.Weapon).MemeServerStagger(STG_KICK, Location);
		W.MemeServerContact(CT_HIT);
	}
}

// ---------------------------------------------------------------- hit stop

simulated function MemeDoHitStop()
{
	local AnimNodeBlendPerBone BPB;

	if (MemeStopSeq != none || MemeHitStopTime <= 0.f)
		return;
	if (BlendAnimationListNode != none && BlendAnimationListNode.ActiveChildIndex < BlendAnimationListNode.Children.Length)
	{
		BPB = AnimNodeBlendPerBone(BlendAnimationListNode.Children[BlendAnimationListNode.ActiveChildIndex].Anim);
		if (BPB != none && BPB.Children.Length > 1)
			MemeStopSeq = AnimNodeSequence(BPB.Children[1].Anim);
	}
	if (OwnerBlendAnimationListNode != none && OwnerBlendAnimationListNode.ActiveChildIndex < OwnerBlendAnimationListNode.Children.Length)
	{
		BPB = AnimNodeBlendPerBone(OwnerBlendAnimationListNode.Children[OwnerBlendAnimationListNode.ActiveChildIndex].Anim);
		if (BPB != none && BPB.Children.Length > 1)
			MemeStopSeqOwner = AnimNodeSequence(BPB.Children[1].Anim);
	}
	if (MemeStopSeq != none)
	{
		MemeStopRate = MemeStopSeq.Rate;
		MemeStopSeq.Rate = MemeStopRate * MemeHitStopRate;
	}
	if (MemeStopSeqOwner != none)
	{
		MemeStopRateOwner = MemeStopSeqOwner.Rate;
		MemeStopSeqOwner.Rate = MemeStopRateOwner * MemeHitStopRate;
	}
	SetTimer(MemeHitStopTime, false, 'MemeEndHitStop');
}

simulated function MemeEndHitStop()
{
	if (MemeStopSeq != none)
		MemeStopSeq.Rate = MemeStopRate;
	if (MemeStopSeqOwner != none)
		MemeStopSeqOwner.Rate = MemeStopRateOwner;
	MemeStopSeq = none;
	MemeStopSeqOwner = none;
}

DefaultProperties
{
	MemeCapDefs(0)=(BoneA=b_Head,BoneB=b_Head,Radius=11.0,HitBone=b_Head)
	MemeCapDefs(1)=(BoneA=b_spine_D,BoneB=b_Neck,Radius=7.0,HitBone=b_Neck)
	MemeCapDefs(2)=(BoneA=b_spine_D,BoneB=b_spine_B,Radius=15.0,HitBone=b_spine_C)
	MemeCapDefs(3)=(BoneA=b_spine_B,BoneB=b_pelvis,Radius=14.0,HitBone=b_spine_A)
	MemeCapDefs(4)=(BoneA=b_l_shoulder,BoneB=b_l_elbow,Radius=5.5,HitBone=b_l_shoulder)
	MemeCapDefs(5)=(BoneA=b_r_shoulder,BoneB=b_r_elbow,Radius=5.5,HitBone=b_r_shoulder)
	MemeCapDefs(6)=(BoneA=b_l_elbow,BoneB=b_l_wrist,Radius=5.0,HitBone=b_l_elbow)
	MemeCapDefs(7)=(BoneA=b_r_elbow,BoneB=b_r_wrist,Radius=5.0,HitBone=b_r_elbow)
	MemeCapDefs(8)=(BoneA=b_pelvis,BoneB=b_l_knee,Radius=8.0,HitBone=b_l_knee)
	MemeCapDefs(9)=(BoneA=b_pelvis,BoneB=b_r_knee,Radius=8.0,HitBone=b_r_knee)
	MemeCapDefs(10)=(BoneA=b_l_knee,BoneB=b_l_ankle,Radius=6.0,HitBone=b_l_ankle)
	MemeCapDefs(11)=(BoneA=b_r_knee,BoneB=b_r_ankle,Radius=6.0,HitBone=b_r_ankle)

`include(MemeMod/Include/MemePawnTuning.uci)
	bMemeDebugDraw=false
}
