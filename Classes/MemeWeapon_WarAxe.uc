class MemeWeapon_WarAxe extends AOCWeapon_WarAxe
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_WarAxe'
}
