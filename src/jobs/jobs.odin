package jobs

//import rl "vendor:raylib"
import "core:math/rand"

JobResult :: enum {
	Inactive,
	Active,
	Finished,
	Failed,
}

Job :: struct {
	name: string,
	level: int,
	is_ready, is_active: bool,
	ticks_needed, ticks_current: int,
	income: f64,
	illegitimate_income: f64,
	details: union {
        StandardJob,
        BuyinJob,
    },
}

StandardJob :: struct {
}

BuyinJob :: struct {
	buyin_price: f64,
	illegitimate_buyin_price: f64,
	failure_chance: f32,
}

tick :: proc(job: ^Job) -> JobResult {
	if !job.is_active do return .Inactive

	switch &d in job.details {
	case StandardJob:
	case BuyinJob:
		if job.ticks_current < job.ticks_needed - 1 && rand.float32() <= d.failure_chance {
			return .Failed
		}
	}

	job.ticks_current += 1
	if job.ticks_current >= job.ticks_needed {
		job.ticks_current -= job.ticks_needed
		return .Finished
	}
	return .Active
}

deactivate :: proc(job: ^Job) {
	job.is_ready = false
    job.is_active = false
    job.ticks_current = 0
}

toggle_state :: proc(job: ^Job) -> bool {
	if !job.is_ready && !job.is_active {
		job.is_ready = true
		return true
	} else {
	    deactivate(job)
	    return false
	}
}