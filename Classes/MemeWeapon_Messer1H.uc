class MemeWeapon_Messer1H extends AOCWeapon_Messer1H
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_Messer1H'
	AlternativeMode=class'MemeWeapon_Messer'
}
