class MemeModLTS extends AOCLTS;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModLTSPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
