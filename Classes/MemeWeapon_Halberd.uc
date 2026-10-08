class MemeWeapon_Halberd extends AOCWeapon_Halberd
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=2
	AttachmentClass=class'MemeWeaponAttachment_Halberd'
}
