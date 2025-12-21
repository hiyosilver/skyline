package types

ActionToggleJob :: struct {
	job_index: int,
}

ActionAssignCrew :: struct {
	job_id:          JobID,
	crew_slot_index: int,
	crew_member_id:  CrewMemberID,
}

ActionClearCrew :: struct {
	job_id:          JobID,
	crew_slot_index: int,
}

ActionBuyStock :: struct {
	company_id: CompanyID,
	amount:     int,
}

ActionSellStock :: struct {
	company_id: CompanyID,
	amount:     int,
}

ActionPurchaseBuilding :: struct {
	building_id: BuildingID,
}

ActionPurchaseBuildingAltPrice :: struct {
	building_id: BuildingID,
}

ActionBuildingToggleLaundering :: struct {
	building_id: BuildingID,
}

ActionBuyUpgrade :: struct {
	building_id: BuildingID,
	upgrade_id:  UpgradeID,
}

GameAction :: union {
	ActionToggleJob,
	ActionAssignCrew,
	ActionClearCrew,
	ActionBuyStock,
	ActionSellStock,
	ActionPurchaseBuilding,
	ActionPurchaseBuildingAltPrice,
	ActionBuildingToggleLaundering,
	ActionBuyUpgrade,
}
