class MemeWeapon_Cudgel extends AOCWeapon_Cudgel
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=0
	AttachmentClass=class'MemeWeaponAttachment_Cudgel'
}
