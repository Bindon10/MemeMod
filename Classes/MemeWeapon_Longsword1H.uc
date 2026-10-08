class MemeWeapon_Longsword1H extends AOCWeapon_Longsword1H
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_Longsword1H'
	AlternativeMode=class'MemeWeapon_Longsword'
}
