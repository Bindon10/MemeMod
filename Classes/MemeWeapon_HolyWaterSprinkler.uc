class MemeWeapon_HolyWaterSprinkler extends AOCWeapon_HolyWaterSprinkler
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=0
	AttachmentClass=class'MemeWeaponAttachment_HolyWaterSprinkler'
}
