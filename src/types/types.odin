package types

import "../textures"
import rl "vendor:raylib"

//Crew
CrewMemberID :: distinct int

CrewMember :: struct {
	id:                                    CrewMemberID,
	nickname:                              string,
	base_salary, base_salary_illegitimate: f64,
	default_job:                           Job,
	brawn, savvy, tech, charisma:          int,
	assigned_to_job_id:                    JobID,
}

//Jobs
JobID :: distinct int

JobResult :: enum {
	Inactive,
	Active,
	Finished,
	Failed,
}

Job :: struct {
	id:                          JobID,
	name:                        string,
	level:                       int,
	is_ready, is_active:         bool,
	ticks_needed, ticks_current: int,
	base_income:                 f64,
	base_illegitimate_income:    f64,
	cached_income:               f64,
	cached_illegitimate_income:  f64,
	details:                     union {
		StandardJob,
		BuyinJob,
	},
}

StandardJob :: struct {
}

BuyinJob :: struct {
	buyin_price:              f64,
	illegitimate_buyin_price: f64,
	base_failure_chance:      f32,
	cached_failure_chance:    f32,
	crew_member_slots:        [dynamic]CrewMemberSlot,
}

CrewMemberSlotType :: enum {
	Brawn,
	Savvy,
	Tech,
	Charisma,
}

CrewMemberSlot :: struct {
	type:                 CrewMemberSlotType,
	assigned_crew_member: CrewMemberID,
}

//Stocks
CompanyID :: distinct int

// Buildings
IncomeMultiplier :: struct {
	multiplier: f64,
}

LaunderingAmountMultiplier :: struct {
	multiplier: f64,
}

LaunderingEfficiencyBonusFlat :: struct {
	bonus: f64,
}

UpgradeEffect :: union {
	IncomeMultiplier,
	LaunderingAmountMultiplier,
	LaunderingEfficiencyBonusFlat,
}

UpgradeID :: distinct int
Upgrade :: struct {
	id:          UpgradeID,
	name:        string,
	description: string,
	cost:        f64,
	purchased:   bool,
	effect:      UpgradeEffect,
}


PurchasePrice :: struct {
	money:              f64,
	illegitimate_money: f64,
}

BuildingEffectStats :: struct {
	income_multiplier:                f64,
	laundering_amount_multiplier:     f64,
	laundering_efficiency_bonus_flat: f64,
}

BuildingID :: distinct int
Building :: struct {
	id:                         BuildingID,
	position:                   rl.Vector2,
	texture_id:                 textures.BuildingTextureId,
	texture_offset:             rl.Vector2,
	image_data:                 rl.Image,
	name:                       string,
	purchase_price:             PurchasePrice,
	alt_purchase_price:         Maybe(PurchasePrice),

	// Effects
	base_tick_income:           f64,
	base_laundering_amount:     f64,
	base_laundering_efficiency: f64,
	effect_stats:               BuildingEffectStats,
	upgrades:                   [dynamic]Upgrade,

	// State
	owned:                      bool,
	hovered:                    bool,
	selected:                   bool,
}
