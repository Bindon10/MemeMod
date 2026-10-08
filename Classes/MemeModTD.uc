class MemeModTD extends AOCTD;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModTDPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
