class MemeModFFA extends AOCFFA;

`include(MemeMod/Include/MemeGame.uci)

// Vanilla sends a scoreless tie into sudden death, which never ends on an empty server. Restart the clock instead.
function AOCEndRound()
{
	local PlayerReplicationInfo PRI;
	local AOCPlayerController PC;

	foreach WorldInfo.GRI.PRIArray(PRI)
	{
		if (PRI.Score != 0)
		{
			super.AOCEndRound();
			return;
		}
	}
	TimeLeft = RoundTime * 60 + 1;
	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
		PC.InitializeTimer(TimeLeft, true);
}

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModFFAPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
