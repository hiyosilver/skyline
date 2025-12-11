package stocks

import "../global"
import "../types"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

CompanySector :: enum {
	CommunicationServices,
	ConsumerDiscretionary,
	ConsumerStaples,
	Energy,
	Financials,
	Healthcare,
	Industrial,
	InformationTechnology,
	Materials,
	RealEstate,
	Utilities,
}

company_sector_display_names := [CompanySector]string {
	.CommunicationServices = "Communication Services",
	.ConsumerDiscretionary = "Consumer Discretionary",
	.ConsumerStaples       = "Consumer Staples",
	.Energy                = "Energy",
	.Financials            = "Financials",
	.Healthcare            = "Healthcare",
	.Industrial            = "Industrial",
	.InformationTechnology = "Information Technology",
	.Materials             = "Materials",
	.RealEstate            = "Real Estate",
	.Utilities             = "Utilities",
}

CreditRating :: enum {
	AAA,
	AA,
	A,
	BBB,
	BB,
	B,
	C,
	D,
}

score_to_rating :: proc(score: int) -> CreditRating {
	switch {
	case score >= 95:
		return .AAA // Perfect
	case score >= 85:
		return .AA // Excellent
	case score >= 75:
		return .A // Solid
	case score >= 60:
		return .BBB // Average
	case score >= 50:
		return .BB // Risky
	case score >= 35:
		return .B // Very Risky
	case score >= 15:
		return .C // Gambling
	case:
		return .D // Dead
	}
}

get_rating_data :: proc(rating: CreditRating) -> (label: string, spread: f64, color: rl.Color) {
	switch rating {
	case .AAA:
		return "AAA", 0.000, rl.Color{0.0, 255.0, 0.0, 255.0} // Bright Green
	case .AA:
		return "AA", 0.010, rl.Color{50.0, 205.0, 50.0, 255.0} // Lime Green
	case .A:
		return "A", 0.020, rl.Color{145.0, 205.0, 50.0, 255.0} // Yellow Green
	case .BBB:
		return "BBB", 0.040, rl.Color{255.0, 255.0, 0.0, 255.0} // Yellow
	case .BB:
		return "BB", 0.065, rl.Color{255.0, 165.0, 0.0, 255.0} // Orange
	case .B:
		return "B", 0.090, rl.Color{255.0, 140.0, 0.0, 255.0} // Dark Orange
	case .C:
		return "C", 0.150, rl.Color{255.0, 69.0, 0.0, 255.0} // Red Orange
	case .D:
		return "D", 0.000, rl.Color{255.0, 0.0, 0.0, 255.0} // Red
	}
	return "?", 0.0, rl.WHITE
}

Company :: struct {
	id:                                                         types.CompanyID,
	name, ticker_symbol, description:                           string,
	sector:                                                     CompanySector,
	years_active:                                               int,
	current_price, expected_price, all_time_low, all_time_high: f64,
	price_history:                                              [dynamic]f64,
	shares_outstanding:                                         int,
	float_percentage:                                           f64,
	earnings_per_share:                                         f64,
	eps_start_of_year:                                          f64,
	perceived_eps:                                              f64,
	revenue_per_share:                                          f64,
	perceived_rps:                                              f64,
	sentiment_multiplier:                                       f64,
	volatility:                                                 f64,
	momentum_equilibrium:                                       f64,
	momentum:                                                   f64,
	growth_rate:                                                f64,
	credit_rating:                                              int,
	payout_ratio:                                               f64,
}

CompanyArchetype :: struct {
	base_eps:                  f64,
	base_sentiment_multiplier: f64,
	base_volatility:           f64,
	base_growth_rate:          f64,
	base_credit_rating:        int,
	base_payout_ratio:         f64,
}

Arch_DividendAristocrat :: CompanyArchetype{5.00, 1.0, 0.05, 0.02, 95, 0.60}
Arch_UtilityGiant :: CompanyArchetype{3.50, 0.9, 0.03, 0.01, 90, 0.70}
Arch_BigTechLeader :: CompanyArchetype{8.00, 1.1, 0.15, 0.10, 85, 0.10}
Arch_GrowthAggressive :: CompanyArchetype{1.50, 1.2, 0.25, 0.18, 60, 0.00}
Arch_Startup :: CompanyArchetype{-0.50, 1.5, 0.60, 0.40, 30, 0.00}
Arch_CommodityCyclical :: CompanyArchetype{2.00, 0.8, 0.35, 0.05, 70, 0.03}
Arch_FinancialAnchor :: CompanyArchetype{4.00, 1.0, 0.20, 0.03, 80, 0.03}
Arch_Distressed :: CompanyArchetype{-2.00, 0.6, 0.45, -0.05, 15, 0.00}

create_company :: proc(
	id: types.CompanyID,
	name, ticker_symbol, description: string,
	sector: CompanySector,
	years_active: int,
	shares_outstanding: int,
	float_percentage: f64,
	archetype: CompanyArchetype,
) -> Company {
	actual_eps := apply_fuzz(archetype.base_eps, 0.2)
	actual_sentiment_multiplier := apply_fuzz(archetype.base_sentiment_multiplier, 0.15)
	actual_vol := apply_fuzz(archetype.base_volatility, 0.1)
	actual_growth := apply_fuzz(archetype.base_growth_rate, 0.2)
	rating_var := int(rand.float64() * 10) - 5
	actual_credit := clamp(archetype.base_credit_rating + rating_var, 1, 100)
	actual_payout := clamp(apply_fuzz(archetype.base_payout_ratio, 0.1), 0.0, 1.0)

	revenue_guess: f64
	if actual_eps > 0 {
		revenue_guess = actual_eps * rand.float64_range(4.5, 6.0)
	} else {
		revenue_guess = math.abs(actual_eps) * rand.float64_range(2.0, 3.0)
	}

	base_val_init := revenue_guess * 0.5
	spec_val_init: f64

	if actual_eps > 0 {
		spec_val_init = actual_eps * 15.0
	} else {
		spec_val_init = revenue_guess * actual_growth * 5.0
	}

	start_price := (base_val_init + spec_val_init) * actual_sentiment_multiplier

	low_price_noise := rand.float64() * 0.2
	high_price_noise := rand.float64() * 0.2

	return Company {
		id = id,
		name = name,
		ticker_symbol = ticker_symbol,
		description = description,
		sector = sector,
		current_price = start_price,
		expected_price = start_price,
		all_time_low = start_price * (1.0 - low_price_noise),
		all_time_high = start_price * (1.0 + high_price_noise),
		price_history = make([dynamic]f64),
		shares_outstanding = shares_outstanding,
		float_percentage = float_percentage,
		earnings_per_share = actual_eps,
		eps_start_of_year = actual_eps,
		perceived_eps = actual_eps,
		sentiment_multiplier = actual_sentiment_multiplier,
		revenue_per_share = revenue_guess,
		perceived_rps = revenue_guess,
		volatility = actual_vol,
		momentum_equilibrium = 1.0,
		momentum = 1.0,
		growth_rate = actual_growth,
		credit_rating = actual_credit,
		payout_ratio = actual_payout,
	}
}


apply_fuzz :: proc(val: f64, variance: f64) -> f64 {
	change := (rand.float64() * 2.0 - 1.0) * variance
	return val * (1.0 + change)
}

Market :: struct {
	global_base_rate:         f64,
	market_cap_start_of_year: f64,
	companies:                map[types.CompanyID]Company,
}

create_market :: proc() -> Market {
	companies := make(map[types.CompanyID]Company)

	//Communication Services
	companies[101] = create_company(
		101,
		"Echo Media",
		"ECHO",
		"News and broadcasting giant",
		.CommunicationServices,
		65,
		1_000_000_000,
		0.95,
		Arch_DividendAristocrat,
	)
	companies[102] = create_company(
		102,
		"Chatterbox",
		"CHAT",
		"Social media platform",
		.CommunicationServices,
		6,
		75_000_000,
		0.4,
		Arch_GrowthAggressive,
	)
	companies[103] = create_company(
		103,
		"Nexus Telecom",
		"NEX",
		"National wireless and internet provider",
		.CommunicationServices,
		45,
		2_500_000_000,
		0.98,
		Arch_UtilityGiant,
	)
	companies[104] = create_company(
		104,
		"Streamline",
		"STRM",
		"Video streaming and content production",
		.CommunicationServices,
		8,
		120_000_000,
		0.60,
		Arch_GrowthAggressive,
	)

	//Consumer Discretionary
	companies[201] = create_company(
		201,
		"Apex Automotive",
		"APEX",
		"Luxury car manufacturer",
		.ConsumerDiscretionary,
		50,
		500_000_000,
		0.55,
		Arch_CommodityCyclical,
	)
	companies[202] = create_company(
		202,
		"Sapphire Resorts",
		"SAPH",
		"Luxury hotel chain",
		.ConsumerDiscretionary,
		13,
		60_000_000,
		0.65,
		Arch_CommodityCyclical,
	)
	companies[203] = create_company(
		204,
		"Velocity Sports",
		"VELO",
		"Athletic footwear and apparel",
		.ConsumerDiscretionary,
		30,
		450_000_000,
		0.85,
		Arch_BigTechLeader,
	)

	//Consumer Staples
	companies[301] = create_company(
		301,
		"Family Mart",
		"FAM",
		"Big-box grocery retailer",
		.ConsumerStaples,
		60,
		10_000_000_000,
		0.9,
		Arch_DividendAristocrat,
	)
	companies[302] = create_company(
		302,
		"Sparkle Beverage",
		"FIZZ",
		"Soft drinks and snacks",
		.ConsumerStaples,
		95,
		3_000_000_000,
		0.92,
		Arch_DividendAristocrat,
	)
	companies[303] = create_company(
		303,
		"Hearth & Home",
		"HAH",
		"Cleaning supplies and paper products",
		.ConsumerStaples,
		70,
		600_000_000,
		0.88,
		Arch_Distressed,
	)

	//Energy
	companies[401] = create_company(
		401,
		"PetroMax",
		"PMAX",
		"Oil and gas",
		.Energy,
		110,
		1_150_000_000,
		0.98,
		Arch_CommodityCyclical,
	)
	companies[402] = create_company(
		402,
		"Helios Renewables",
		"HEL",
		"Solar panel manufacturing and farms",
		.Energy,
		12,
		150_000_000,
		0.70,
		Arch_GrowthAggressive,
	)

	//Financials
	companies[501] = create_company(
		501,
		"Sterling Trust",
		"STER",
		"Wealth management services",
		.Financials,
		89,
		30_000_000,
		0.85,
		Arch_FinancialAnchor,
	)
	companies[502] = create_company(
		502,
		"Pinnacle Capital",
		"PIN",
		"Investment banking",
		.Financials,
		12,
		25_000_000,
		0.8,
		Arch_GrowthAggressive,
	)
	companies[503] = create_company(
		503,
		"PayFlow Systems",
		"PAY",
		"Global credit card processing",
		.Financials,
		25,
		900_000_000,
		0.80,
		Arch_BigTechLeader,
	)
	companies[504] = create_company(
		504,
		"Aegis Insurance",
		"AEGS",
		"Property and casualty insurance",
		.Financials,
		110,
		400_000_000,
		0.95,
		Arch_FinancialAnchor,
	)

	//Healthcare
	companies[601] = create_company(
		601,
		"AstraCare",
		"AST",
		"Nursing homes and elderly care",
		.Healthcare,
		46,
		67_000_000,
		0.9,
		Arch_DividendAristocrat,
	)
	companies[602] = create_company(
		602,
		"Helix Therapeutics",
		"HLX",
		"Gene editing research",
		.Healthcare,
		4,
		30_000_000,
		0.40,
		Arch_Startup,
	)

	//Industrial
	companies[701] = create_company(
		701,
		"Condor Industries",
		"CDI",
		"Aerospace",
		.Industrial,
		35,
		177_000_000,
		0.8,
		Arch_BigTechLeader,
	)
	companies[702] = create_company(
		702,
		"Arrow Logistics",
		"ARR",
		"Global package delivery",
		.Industrial,
		40,
		350_000_000,
		0.90,
		Arch_CommodityCyclical,
	)
	companies[703] = create_company(
		703,
		"Vanguard",
		"VGD",
		"Military aircraft and systems",
		.Industrial,
		70,
		200_000_000,
		0.80,
		Arch_FinancialAnchor,
	)

	//Information Technology
	companies[801] = create_company(
		801,
		"DataSphere",
		"DATA",
		"Cloud storage and big data",
		.InformationTechnology,
		20,
		1_000_000_000,
		0.6,
		Arch_BigTechLeader,
	)
	companies[802] = create_company(
		803,
		"Sentinel Cyber",
		"LOCK",
		"Enterprise network security",
		.InformationTechnology,
		9,
		80_000_000,
		0.50,
		Arch_GrowthAggressive,
	)

	//Materials
	companies[901] = create_company(
		901,
		"Strateon Mining",
		"STRA",
		"Cloud storage and big data",
		.Materials,
		75,
		70_000_000,
		0.45,
		Arch_CommodityCyclical,
	)
	companies[902] = create_company(
		902,
		"Titan Steel",
		"TITN",
		"Industrial steel production",
		.Materials,
		85,
		250_000_000,
		0.85,
		Arch_CommodityCyclical,
	)

	//Real Estate
	companies[1001] = create_company(
		1001,
		"Horizon Properties",
		"HRZN",
		"Residential apartment complexes",
		.RealEstate,
		40,
		52_000_000,
		0.85,
		Arch_FinancialAnchor,
	)
	companies[1002] = create_company(
		1002,
		"MetroLiving",
		"MTRO",
		"Low income housing",
		.RealEstate,
		25,
		18_000_000,
		0.78,
		Arch_UtilityGiant,
	)
	companies[1003] = create_company(
		1003,
		"Foundation",
		"FND",
		"Mortgage investment trust",
		.RealEstate,
		15,
		48_000_000,
		0.9,
		Arch_FinancialAnchor,
	)

	//Utilities
	companies[1101] = create_company(
		1101,
		"VitalWay",
		"VIT",
		"Natural gas distribution",
		.Utilities,
		80,
		500_000_000,
		0.99,
		Arch_UtilityGiant,
	)
	companies[1102] = create_company(
		1102,
		"AquaSource",
		"AQUA",
		"Municipal water treatment",
		.Utilities,
		75,
		150_000_000,
		0.95,
		Arch_UtilityGiant,
	)

	market := Market {
		global_base_rate = 0.05,
		companies        = companies,
	}
	market_cap := calculate_total_market_cap(&market)
	market.market_cap_start_of_year = market_cap

	return market
}

calculate_total_market_cap :: proc(market: ^Market) -> f64 {
	total: f64 = 0
	for _, company in market.companies {
		cap := company.current_price * f64(company.shares_outstanding)
		total += cap
	}
	return total
}

update_stock_price :: proc(company: ^Company) {
	base_value := company.perceived_rps * 0.5

	speculative_value: f64
	if company.perceived_eps > 0 {
		speculative_value = company.perceived_eps * 15.0
	} else {
		speculative_value = company.perceived_rps * company.growth_rate * 5.0
	}

	raw_price := (base_value + speculative_value) * company.sentiment_multiplier * company.momentum
	raw_price = math.max(raw_price, 0.01)

	company.current_price = math.lerp(company.current_price, raw_price, 0.05)

	append(&company.price_history, company.current_price)
	if len(company.price_history) > 30 {
		ordered_remove(&company.price_history, 0)
	}

	if company.current_price > company.all_time_high {
		company.all_time_high = company.current_price
		company.expected_price = company.current_price
	} else if company.current_price < company.all_time_low {
		company.all_time_low = company.current_price
	}
}

update_market_tick :: proc(market: ^Market) {
	ticks_per_year := f64(
		global.TICKS_PER_PERIOD * global.PERIODS_PER_QUARTER * global.QUARTERS_PER_YEAR,
	)
	sqrt_time_tick := math.sqrt(ticks_per_year)

	market_reaction_speed := 0.05

	for _, &company in market.companies {
		noise := company.volatility / sqrt_time_tick
		sentiment_shift := (rand.float64() - 0.5) * noise

		company.sentiment_multiplier *= (1.0 + sentiment_shift)
		company.sentiment_multiplier = clamp(company.sentiment_multiplier, 0.5, 3.0)

		company.momentum = math.lerp(company.momentum, company.momentum_equilibrium, 0.1)

		company.perceived_eps = math.lerp(
			company.perceived_eps,
			company.earnings_per_share,
			market_reaction_speed,
		)
		company.perceived_rps = math.lerp(
			company.perceived_rps,
			company.revenue_per_share,
			market_reaction_speed,
		)

		update_stock_price(&company)
	}
}

update_market_period :: proc(market: ^Market) {
	sector_count := len(CompanySector)
	lucky_sector_index := rand.int_max(sector_count)
	lucky_sector := CompanySector(lucky_sector_index)
	unlucky_sector_index := (lucky_sector_index + 1 + rand.int_max(sector_count)) % sector_count
	unlucky_sector := CompanySector(unlucky_sector_index)

	for _, &company in market.companies {
		company.momentum_equilibrium = math.lerp(company.momentum_equilibrium, 1.0, 0.2)
		if company.sector == lucky_sector {
			company.momentum_equilibrium *= 1.02
		} else if company.sector == unlucky_sector {
			company.momentum_equilibrium *= 0.98
		}
	}

	// PAY BOND INTEREST
}

update_market_quarter :: proc(market: ^Market) {
	quarters_per_year := f64(global.QUARTERS_PER_YEAR)
	sqrt_time_period := math.sqrt(quarters_per_year)

	for _, &company in market.companies {
		expected_growth := company.growth_rate / quarters_per_year
		quarter_volatility := company.volatility / sqrt_time_period
		random_sigma := clamp(rand.norm_float64(), -2.0, 2.0)
		actual_period_growth := expected_growth + (quarter_volatility * random_sigma)

		magnitude := math.abs(company.earnings_per_share)
		if magnitude < 0.10 {
			magnitude = 0.10
		}

		delta := magnitude * actual_period_growth

		company.earnings_per_share += delta

		growth_factor := actual_period_growth * 0.8

		company.revenue_per_share *= (1.0 + growth_factor)

		if company.revenue_per_share < company.earnings_per_share {
			company.revenue_per_share = company.earnings_per_share * 1.1
		}

		update_stock_price(&company)

		rating_change := 0
		if company.current_price < (company.expected_price * 0.5) {
			if rand.float64() < 0.5 do rating_change -= 2
			company.expected_price *= 0.8
		} else if company.earnings_per_share < 0 {
			if rand.float64() < 0.2 do rating_change -= 1
		} else if company.current_price < 5.0 {
			if rand.float64() < 0.1 do rating_change -= 1
		} else {
			if rand.float64() < 0.1 do rating_change += 1
		}

		company.credit_rating += rating_change
		company.credit_rating = clamp(company.credit_rating, 0, 100)

		// PAY DIVIDENDS
	}
}

update_market_year :: proc(market: ^Market) {
	current_total_cap := calculate_total_market_cap(market)
	percent_change :=
		(current_total_cap - market.market_cap_start_of_year) / market.market_cap_start_of_year
	market.market_cap_start_of_year = current_total_cap

	old_rate := market.global_base_rate

	if percent_change > 0.25 {
		market.global_base_rate += 0.005
	} else if percent_change < -0.10 {
		market.global_base_rate -= 0.005
	}
	market.global_base_rate = clamp(market.global_base_rate, 0.01, 0.15)

	rate_delta := market.global_base_rate - old_rate
	valuation_shock := -(rate_delta * 15.0)

	for _, &company in market.companies {
		company.years_active += 1

		if !global.is_approx_zero(rate_delta) {
			company.sentiment_multiplier *= (1.0 + valuation_shock)
			company.sentiment_multiplier = clamp(company.sentiment_multiplier, 0.5, 3.0)
		}

		decay_factor: f64 = 1.0

		if company.years_active >= 20 {
			decay_factor = 0.95
		} else if company.years_active >= 10 {
			decay_factor = 0.98
		} else if company.years_active >= 3 {
			decay_factor = 0.99
		} else {
			decay_factor = 1.0
		}

		company.growth_rate *= decay_factor

		retained_pct := 1.0 - company.payout_ratio
		efficiency: f64

		if company.growth_rate < 0 {
			efficiency = 0.008
		} else if company.years_active < 10 {
			efficiency = 0.005
		} else {
			efficiency = 0.002
		}

		company.growth_rate += retained_pct * efficiency

		if company.growth_rate > 0.50 {company.growth_rate = 0.50}

		target_volatility: f64 = 0.0

		if company.years_active >= 20 {
			target_volatility = 0.1
		} else if company.years_active >= 10 {
			target_volatility = 0.2
		} else {
			target_volatility = 0.4
		}

		if company.credit_rating < 40 {
			target_volatility = 0.8
		} else if company.credit_rating < 60 {
			target_volatility = 0.5
		}

		company.volatility = math.lerp(company.volatility, target_volatility, 0.10)

		company.volatility = clamp(company.volatility, 0.05, 1.5)

		//Recalculate dividend payouts
		eps_delta_percent: f64 = 0.0

		if math.abs(company.eps_start_of_year) > 0.01 {
			eps_delta_percent =
				(company.earnings_per_share - company.eps_start_of_year) /
				math.abs(company.eps_start_of_year)
		}

		target_ratio: f64 = 0.50

		if company.years_active <
		   5 {target_ratio = 0.0} else if company.years_active < 15 {target_ratio = 0.15}

		if eps_delta_percent < -0.10 {
			target_ratio *= 0.5
		} else if eps_delta_percent < 0.10 {
			target_ratio *= 0.9
		} else {
			target_ratio *= 1.1
		}

		target_ratio = clamp(target_ratio, 0.0, 0.80)

		company.payout_ratio = math.lerp(company.payout_ratio, target_ratio, 0.10)

		company.eps_start_of_year = company.earnings_per_share
	}
}

close_market :: proc(market: ^Market) {
	for _, &company in market.companies {
		delete(company.price_history)
	}
	delete(market.companies)
}

StockInfo :: struct {
	company_id:     types.CompanyID,
	quantity_owned: int,
	average_cost:   f64,
}

StockPortfolio :: struct {
	stocks: map[types.CompanyID]StockInfo,
}

create_stock_portfolio :: proc(market: ^Market) -> StockPortfolio {
	stocks_data := make(map[types.CompanyID]StockInfo)
	for company_id, _ in market.companies {
		stocks_data[company_id] = StockInfo {
			company_id = company_id,
		}
	}
	return StockPortfolio{stocks_data}
}

get_available_shares :: proc(company: ^Company, stock_info: ^StockInfo) -> int {
	return(
		int(f64(company.shares_outstanding) * company.float_percentage) -
		stock_info.quantity_owned \
	)
}

TradeResult :: enum {
	Success,
	InsufficientFunds,
	InsufficientShares,
	InvalidCompany,
}

execute_buy_order :: proc(
	market: ^Market,
	portfolio: ^StockPortfolio,
	money: ^f64,
	company_id: types.CompanyID,
	amount: int,
) -> TradeResult {
	company, ok := &market.companies[company_id]
	if !ok do return .InvalidCompany

	stock_info := &portfolio.stocks[company_id]

	total_cost := company.current_price * f64(amount)

	if money^ < total_cost do return .InsufficientFunds

	available_shares := get_available_shares(company, stock_info)

	if available_shares < amount do return .InsufficientShares

	money^ -= total_cost

	stock_info.average_cost =
		(f64(stock_info.quantity_owned) * stock_info.average_cost +
			f64(amount) * company.current_price) /
		f64(stock_info.quantity_owned + amount)

	stock_info.quantity_owned += amount

	return .Success
}

execute_sell_order :: proc(
	market: ^Market,
	portfolio: ^StockPortfolio,
	money, period_income: ^f64,
	company_id: types.CompanyID,
	amount: int,
) -> TradeResult {
	company, ok := market.companies[company_id]
	if !ok do return .InvalidCompany

	stock_info := &portfolio.stocks[company_id]

	if stock_info.quantity_owned < amount do return .InsufficientShares

	payout := company.current_price * f64(amount)
	cost_basis := stock_info.average_cost * f64(amount)

	stock_info.quantity_owned -= amount
	if stock_info.quantity_owned == 0 {
		stock_info.average_cost = 0.0
	}

	money^ += payout
	period_income^ += payout - cost_basis

	return .Success
}

delete_stock_portfolio :: proc(portfolio: ^StockPortfolio) {
	delete(portfolio.stocks)
}
