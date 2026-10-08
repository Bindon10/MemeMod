class MemeModKOTH extends AOCKOTH;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModKOTHPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
