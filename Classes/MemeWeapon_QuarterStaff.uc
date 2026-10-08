class MemeWeapon_QuarterStaff extends AOCWeapon_QuarterStaff
	implements(IMemeWeapon);

`include(MemeMod/Include/MemeWeapon.uci)

DefaultProperties
{
`include(MemeMod/Include/MemeWeaponDefaults.uci)
	MMass=1
	AttachmentClass=class'MemeWeaponAttachment_QuarterStaff'
}
