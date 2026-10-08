class MemeWeapon_Falchion extends AOCWeapon_Falchion
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=0
	AttachmentClass=class'MemeWeaponAttachment_Falchion'
}
