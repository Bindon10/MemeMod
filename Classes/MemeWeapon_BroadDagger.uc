class MemeWeapon_BroadDagger extends AOCWeapon_BroadDagger
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=0
	AttachmentClass=class'MemeWeaponAttachment_BroadDagger'
}
