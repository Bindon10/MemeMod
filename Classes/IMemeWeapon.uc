interface IMemeWeapon;

// Implemented by every MemeWeapon_* through Include/MemeWeapon.uci.

simulated function bool MemeIsStriking();
simulated function bool MemeIsWindingUp();
simulated function bool MemeIsGuarding();
simulated function bool MemeInParryWindow();
simulated function bool MemeIsHyperArmored();
simulated function bool MemeIsStaggered();
simulated function bool MemeIsShieldGuard();
simulated function float MemeStrikeStart();
simulated function float MemeStrikeProgress();
simulated function byte MemeAttackType();
simulated function bool MemeAttackIsAlt();
simulated function byte MemeMassClass();
simulated function float MemeWindupEnd();
simulated function bool MemeCanFeint();
simulated function bool MemeCanRiposte();
simulated function bool MemeIsHolding();
simulated function MemeReleaseHold();
simulated function bool MemeIsVulnerable();
simulated function bool MemeGetTurnCaps(out float YawCap, out float PitchCap);

function MemeServerStagger(byte Kind, vector FromLocation);
function MemeServerRecoil(byte Cause, float Length, bool bChainAfter);
function MemeServerBlocked(bool bPerfect, byte Dir);
function MemeServerContact(byte Kind);
