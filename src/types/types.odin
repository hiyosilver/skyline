package types

import "../textures"
import rl "vendor:raylib"

// Crew
CrewMemberID :: distinct int

CrewMember :: struct {
	id:                                    CrewMemberID,
	nickname:                              string,
	base_salary, base_salary_illegitimate: f64,
	default_job:                           Job,
	brawn, savvy, tech, charisma:          i32,
	assigned_to_job_id:                    JobID,
}

// Jobs
JobID :: distinct int

JobResult :: enum {
	Inactive,
	Active,
	Finished,
	Failed,
}

Job :: struct {
	// Identity
	id:                          JobID,
	name:                        string,
	description:                 string,
	level:                       int,

	// State
	is_ready, is_active:         bool,
	ticks_needed, ticks_current: int,

	// Output
	base_income:                 f64,
	base_illegitimate_income:    f64,
	cached_income:               f64,
	cached_illegitimate_income:  f64,

	// Input
	buyin_price:                 f64,
	illegitimate_buyin_price:    f64,
	crew_member_slots:           [dynamic]CrewMemberSlot,

	// Risk
	base_failure_chance:         f32,
	cached_failure_chance:       f32,
}

CrewMemberSlotType :: enum {
	Brawn,
	Savvy,
	Tech,
	Charisma,
}

CrewMemberSlotEffectType :: enum {
	IncomeIncreasePercent,
	IllegitimateIncomeIncreasePercent,
	FailureChangeReductionFlat,
}

CrewMemberSlotEffect :: struct {
	type:   CrewMemberSlotEffectType,
	amount: f64,
}

CrewMemberSlot :: struct {
	type:                 CrewMemberSlotType,
	effects:              [dynamic]CrewMemberSlotEffect,
	optional:             bool,
	assigned_crew_member: CrewMemberID,
}

// Heists
HeistID :: distinct int

HeistStage :: enum {
	Idle,
	Planning,
	Execution,
	Finish,
}

Heist :: struct {
	// Identity
	id:                       HeistID,
	name:                     string,
	description:              string,

	// Input
	crew_member_slots:        [dynamic]CrewMemberSlot,

	// State
	stage:                    HeistStage,
	planning_ticks_needed:    int,
	planning_ticks_current:   int,
	planning_retries_base:    int,
	planning_retries_current: int,
	planning_success:         f32,
	execution_ticks_needed:   int,
	execution_ticks_current:  int,
	finish_ticks_needed:      int,
	finish_ticks_current:     int,

	// Output
	base_payout:              f64,
	cached_payout:            f64,
}

// Stocks
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
	is_laundering:              bool,
	effect_stats:               BuildingEffectStats,
	upgrades:                   [dynamic]Upgrade,

	// State
	owned:                      bool,
	hovered:                    bool,
	selected:                   bool,
}
