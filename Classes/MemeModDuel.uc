class MemeModDuel extends AOCDuel;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModDuelPlayerController'
	DefaultAIControllerClass=class'MemeAIDuelController'
}
