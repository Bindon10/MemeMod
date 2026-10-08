class MemeWeapon_PickAxe extends AOCWeapon_PickAxe
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=2
	AttachmentClass=class'MemeWeaponAttachment_PickAxe'
}
