class MemeWeapon_Messer extends AOCWeapon_Messer
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_Messer'
	AlternativeMode=class'MemeWeapon_Messer1H'
}
