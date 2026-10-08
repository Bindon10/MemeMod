class MemeWeapon_Saber extends AOCWeapon_Saber
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=0
	AttachmentClass=class'MemeWeaponAttachment_Saber'
}
