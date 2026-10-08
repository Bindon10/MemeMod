class MemeWeapon_SwordOfWar extends AOCWeapon_SwordOfWar
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_SwordOfWar'
	AlternativeMode=class'MemeWeapon_SwordOfWar1H'
}
