class MemeWeapon_PoleHammer extends AOCWeapon_PoleHammer
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=2
	AttachmentClass=class'MemeWeaponAttachment_PoleHammer'
}
