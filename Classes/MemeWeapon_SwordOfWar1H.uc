class MemeWeapon_SwordOfWar1H extends AOCWeapon_SwordOfWar1H
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_SwordOfWar1H'
	AlternativeMode=class'MemeWeapon_SwordOfWar'
}
