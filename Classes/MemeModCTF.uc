class MemeModCTF extends AOCCTF;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModCTFPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
