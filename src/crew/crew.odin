package crew

import "../types"
import "core:math/rand"

nicknames := [58]string {
	"Ace",
	"Angel",
	"Blast",
	"Brain",
	"Bugs",
	"Bullet",
	"Brick",
	"Bones",
	"Chains",
	"Chicken",
	"Crow",
	"Chrome",
	"Crash",
	"Cash",
	"Dagger",
	"Diesel",
	"Duke",
	"Dutch",
	"Fingers",
	"Gator",
	"Ghost",
	"Grease",
	"Hammer",
	"Havoc",
	"Hot Rod",
	"Ice",
	"Jinx",
	"Junior",
	"Knuckles",
	"Lefty",
	"Lucky",
	"Mad Dog",
	"Moose",
	"Nitro",
	"Plug",
	"Razor",
	"Red",
	"Rook",
	"Shorty",
	"Smoke",
	"Snake",
	"Slick",
	"Shadow",
	"Spider",
	"Stitches",
	"Spike",
	"Slash",
	"Slim",
	"Smokey",
	"Tiny",
	"Trigger",
	"Twitch",
	"Two-Bit",
	"Vandal",
	"Viper",
	"Weasel",
	"Wildcard",
	"Wrench",
}
current_nickname_index := rand.int_max(len(nicknames))

@(init)
setup :: proc() {
	rand.shuffle(nicknames[:])
}

generate_crew_member :: proc() -> types.CrewMember {
	@(static) id: types.CrewMemberID = 1
	defer id += 1

	crew_member := types.CrewMember {
		id = id,
		nickname = nicknames[current_nickname_index],
		base_salary = 0.5,
		base_salary_illegitimate = 0.5,
		default_job = {
			name = "Hustle",
			level = 1,
			is_ready = true,
			ticks_needed = 4,
			illegitimate_income = 2.0,
			details = types.StandardJob{},
		},
		brawn = 1,
		savvy = 1,
		tech = 1,
		charisma = 1,
	}

	current_nickname_index += 1
	current_nickname_index %= len(nicknames)

	return crew_member
}
