class MemeWeapon_Greatsword extends AOCWeapon_Greatsword
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=2
	AttachmentClass=class'MemeWeaponAttachment_Greatsword'
}
