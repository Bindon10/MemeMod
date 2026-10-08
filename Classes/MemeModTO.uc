class MemeModTO extends AOCTeamObjective;

`include(MemeMod/Include/MemeGame.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeGameDefaults.uci)
	PlayerControllerClass=class'MemeModTOPlayerController'
	DefaultAIControllerClass=class'MemeAIController'
}
