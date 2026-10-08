class MemeWeapon_Longsword extends AOCWeapon_Longsword
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_Longsword'
	AlternativeMode=class'MemeWeapon_Longsword1H'
}
