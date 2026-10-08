class MemeWeapon_Bearded extends AOCWeapon_Bearded
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=2
	AttachmentClass=class'MemeWeaponAttachment_Bearded'
}
