package stocks

import "core:math/rand"

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

company_category_display_names := [CompanySector]string {
	.CommunicationServices = "Communication Services",
	.ConsumerDiscretionary = "Consumer Discretionary",
	.ConsumerStaples = "Consumer Staples",
	.Energy = "Energy",
	.Financials = "Financials",
	.Healthcare = "Healthcare",
	.Industrial = "Industrial",
	.InformationTechnology = "Information Technology",
	.Materials = "Materials",
	.RealEstate = "Real Estate",
	.Utilities = "Utilities",
}

CompanyID :: distinct int

Company :: struct {
	id: CompanyID,
	name, ticker_symbol, description: string,
	category: CompanySector,

	current_price, all_time_low, all_time_high: f64,
	price_history: [dynamic]f64,
	shares_outstanding: int,
	float_percentage: f64,
	volatility: f64,
}

create_company :: proc(id: CompanyID, name, ticker_symbol, description: string, category: CompanySector, current_price: f64, shares_outstanding: int, float_percentage: f64, volatility: f64) -> Company {
	return Company{
		id = id,
		name = name,
		ticker_symbol = ticker_symbol,
		description = description,
		category = category,
		current_price = current_price,
		all_time_low = current_price,
		all_time_high = current_price,
		price_history = make([dynamic]f64),
		shares_outstanding = shares_outstanding,
		float_percentage = float_percentage,
		volatility = volatility,
	}
}

StockMarket :: struct {
	companies: map[CompanyID]Company,
}

create_stock_market :: proc() -> StockMarket {
	companies := make(map[CompanyID]Company)

	//Communication Services
	companies[101] = create_company(101, "Echo Media", "ECHO", "News and broadcasting giant", .CommunicationServices, 45.0, 1_000_000_000, 0.95, 0.05)
	companies[102] = create_company(102, "Chatterbox", "CHAT", "Social media platform", .CommunicationServices, 67.0, 75_000_000, 0.4, 0.075)

	//Consumer Discretionary
	companies[201] = create_company(201, "Apex Automotive", "APEX", "Luxury car manufacturer", .ConsumerDiscretionary, 172.0, 500_000_000, 0.55, 0.2)
	companies[202] = create_company(202, "Sapphire Resorts", "SAPH", "Luxury hotel chain", .ConsumerDiscretionary, 413.0, 60_000_000, 0.65, 0.35)

	//Consumer Staples
	companies[301] = create_company(301, "Family Mart", "FAM", "Big-box grocery retailer", .ConsumerStaples, 23.0, 10_000_000_000, 0.9, 0.05)

	//Energy
	companies[401] = create_company(401, "PetroMax", "PMAX", "Oil and gas", .Energy, 261.0, 1_150_000_000, 0.98, 0.45)

	//Financials
	companies[501] = create_company(501, "Sterling Trust", "STER", "Wealth management services", .Financials, 259.0, 30_000_000, 0.85, 0.15)
	companies[502] = create_company(502, "Pinnacle Capital", "STER", "Investment banking", .Financials, 318.0, 25_000_000, 0.8, 0.22)

	//Healthcare
	companies[601] = create_company(601, "AstraCare", "AST", "Nursing homes and elderly care", .Healthcare, 89.0, 67_000_000, 0.9, 0.15)

	//Industrial
	companies[701] = create_company(701, "Condor Industries", "CDI", "Aerospace", .Industrial, 339.0, 177_000_000, 0.8, 0.125)

	//Information Technology
	companies[801] = create_company(801, "DataSphere", "DATA", "Cloud storage and big data", .InformationTechnology, 125.0, 1_000_000_000, 0.6, 0.8)

	//Materials
	companies[901] = create_company(901, "Strateon Mining", "STRA", "Cloud storage and big data", .Materials, 17.0, 70_000_000, 0.45, 0.3)

	//Real Estate
	companies[1001] = create_company(1001, "Horizon Properties", "HRZN", "Residential apartment complexes", .RealEstate, 104.0, 52_000_000, 0.85, 0.1)
	companies[1002] = create_company(1002, "MetroLiving", "MTRO", "Low income housing", .RealEstate, 43.0, 18_000_000, 0.78, 0.075)
	companies[1003] = create_company(1003, "Foundation", "FND", "Mortgage investment trust", .RealEstate, 413.0, 48_000_000, 0.9, 0.12)

	//Utilities
	companies[1101] = create_company(1101, "VitalWay", "VIT", "Natural gas distribution", .Utilities, 76.0, 500_000_000, 0.99, 0.01)

	return StockMarket{companies}
}

update_stock_market :: proc(market: ^StockMarket) {
	for _, &company in market.companies {
		random_spread := (rand.float64() - 0.5) * 2.0
		company.current_price += random_spread * company.volatility
	}
}

close_stock_market :: proc(market: ^StockMarket) {
	for _, &company in market.companies {
		delete(company.price_history)
	}
	delete(market.companies)
}

StockInfo :: struct {
	company_id: CompanyID,
	quantity_owned: int,
	average_cost: f64,
}

StockPortfolio :: struct {
	stocks: map[CompanyID]StockInfo,
}

create_stock_portfolio :: proc(market: ^StockMarket) -> StockPortfolio {
	stocks_data := make(map[CompanyID]StockInfo)
	for company_id, _ in market.companies {
		stocks_data[company_id] = StockInfo {
			company_id = company_id,
		}
	}
	return StockPortfolio{stocks_data}
}

get_available_shares :: proc(company: ^Company, stock_info: ^StockInfo) -> int {
	return int(f64(company.shares_outstanding) * company.float_percentage) - stock_info.quantity_owned
}

TradeResult :: enum {
	Success,
	InsufficientFunds,
	InsufficientShares,
	InvalidCompany,
}

execute_buy_order :: proc(market: ^StockMarket, portfolio: ^StockPortfolio, money: ^f64, company_id: CompanyID, amount: int) -> TradeResult {
	company, ok := &market.companies[company_id]
	if !ok do return .InvalidCompany

	stock_info := &portfolio.stocks[company_id]

	total_cost := company.current_price * f64(amount)

	if money^ < total_cost do return .InsufficientFunds

	available_shares := get_available_shares(company, stock_info)

	if available_shares < amount do return .InsufficientShares

	money^ -= total_cost

	stock_info.average_cost = (f64(stock_info.quantity_owned) * stock_info.average_cost + f64(amount) * company.current_price) / f64(stock_info.quantity_owned + amount)

	stock_info.quantity_owned += amount

	return .Success
}

execute_sell_order :: proc(market: ^StockMarket, portfolio: ^StockPortfolio, money, period_income: ^f64, company_id: CompanyID, amount: int) -> TradeResult {
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
