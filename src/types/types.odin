package types

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
	income:                      f64,
	illegitimate_income:         f64,
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
	failure_chance:           f32,
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
