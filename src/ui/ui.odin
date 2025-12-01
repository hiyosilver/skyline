package ui

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
import "../crew"
import "../global"
import "../input"
import "../jobs"
import "../stocks"
import "../textures"

Component :: struct {
	position, size, min_size, desired_size: rl.Vector2,
	variant: ComponentVariant,
	state: ComponentState,
}

ComponentState :: enum {
	Active, //Default
	Hidden, //Invisible, but still takes up space
	Inactive, //Invisible and no area for purposes of space calculation
}

ComponentVariant :: union {
	StackContainer,
	AnchorContainer,
	BoxContainer,
	MarginContainer,
	ScrollContainer,
	Panel,
	Pill,
	SimpleButton,
	RadioButton,
	CheckBox,
	Label,
	LoadingBar,
	Graph,
}

make_component :: proc(variant: Component) -> ^Component {
	c := new(Component)
	c^ = variant
	return c
}

StackContainer :: struct {
	children: [dynamic]^Component,
}

make_stack :: proc(children: ..^Component) -> ^Component {
	c := new(Component)
	stack := StackContainer{
		children = make([dynamic]^Component),
	}
	for child in children do append(&stack.children, child)
	c.variant = stack
	return c
}

AnchorType :: enum {
	TopLeft,
	Top,
	TopRight,
	Left,
	Center,
	Right,
	BottomLeft,
	Bottom,
	BottomRight,
}

AnchorContainer :: struct {
	child: ^Component,
	type: AnchorType,
}

make_anchor :: proc(type: AnchorType, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.variant = AnchorContainer{
		type  = type,
		child = child,
	}

	return c
}

BoxDirection :: enum {
	Vertical,
	Horizontal,
}

BoxMainAlignment :: enum {
	Start,
	Center,
	End,
	Fill,
	SpaceBetween,
	SpaceEvenly,
}

BoxCrossAlignment :: enum {
	Start,
	Center,
	End,
	Fill,
}

BoxContainer :: struct {
	children: [dynamic]^Component,
	direction: BoxDirection,
	main_alignment: BoxMainAlignment,
	cross_alignment: BoxCrossAlignment,
	gap: int,
}

make_box :: proc(direction: BoxDirection, main: BoxMainAlignment, cross: BoxCrossAlignment, gap: int, children: ..^Component) -> ^Component {
	c := new(Component)

	box := BoxContainer{
		direction = direction,
		main_alignment = main,
		cross_alignment = cross,
		gap = gap,
		children = make([dynamic]^Component),
	}

	for child in children do append(&box.children, child)

	c.variant = box
	return c
}

box_add_child :: proc(box: ^Component, child: ^Component) {
	if b, ok := &box.variant.(BoxContainer); ok {
		append(&b.children, child)
	}
}

box_remove_child :: proc(box: ^Component, child_to_remove: ^Component) {
	if b, ok := &box.variant.(BoxContainer); ok {
		for child_ptr, i in b.children {
			if child_ptr == child_to_remove {
				ordered_remove(&b.children, i)
				return
			}
		}
	}
}

MarginContainer :: struct {
	child: ^Component,
	margin_top, margin_right, margin_bottom, margin_left: int,
}

make_margin :: proc(margin_top, margin_right, margin_bottom, margin_left: int, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.variant = MarginContainer{
		margin_top  = margin_top,
		margin_right  = margin_right,
		margin_bottom  = margin_bottom,
		margin_left  = margin_left,
		child = child,
	}

	return c
}

ScrollContainer :: struct {
	child: ^Component,
	scroll_y:        f32,        // Tracks how far the view is scrolled down
    content_height:  f32,        // Calculated max height of the content
    viewport_height: f32,        // The height the parent allocated to this container
    scrollable_range: f32,       // content_height - viewport_height
}

make_scroll_container :: proc(min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
    c := new(Component)
    c.min_size = min_size

    c.variant = ScrollContainer{
        child = child,
    }
    return c
}

Panel :: struct {
	child: ^Component,
	color: rl.Color,
}

make_panel :: proc(color: rl.Color, min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Panel{
		color    = color,
		child    = child,
	}

	return c
}

Pill :: struct {
	child: ^Component,
	color: rl.Color,
}

make_pill :: proc(color: rl.Color, min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Pill{
		color    = color,
		child    = child,
	}

	return c
}

SimpleButtonState :: enum {
	Idle,
	Disabled,
	Hovered,
	Pressed,
	Released,
}

SimpleButtonClickType :: enum {
	OnPress,
	OnRelease,
}

SimpleButton :: struct {
	child:      ^Component,
	state: SimpleButtonState,
	click_type: SimpleButtonClickType,
	color_default, color_hovered, color_pressed: rl.Color,
	padding: f32,
}

make_simple_button :: proc(click_type: SimpleButtonClickType, color: rl.Color, min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = SimpleButton{
		state = .Idle,
		click_type = click_type,
		color_default = color,
		color_hovered = rl.ColorBrightness(color, 0.2),
		color_pressed = rl.ColorBrightness(color, -0.2),
		padding = 4.0,
		child    = child,
	}

	return c
}

button_was_clicked :: proc(component: ^Component) -> bool {
	if component == nil do return false
	if btn, ok := component.variant.(SimpleButton); ok {
		return btn.state == .Released
	}
	return false
}

button_set_disabled :: proc(component: ^Component, disabled: bool) {
	if component == nil do return
	if btn, ok := &component.variant.(SimpleButton); ok {
		if disabled {
			btn.state = .Disabled
		} else {
			if btn.state == .Disabled {
				btn.state = .Idle
			}
		}
	}
}

RadioButton :: struct {
	selected: bool,
	state: SimpleButtonState,
	connected_radio_buttons: [dynamic]^Component,
}

make_radio_button :: proc(min_size: rl.Vector2 = {20.0, 20.0}, selected: bool = false) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = RadioButton{
		selected = selected,
		state = .Idle,
		connected_radio_buttons = make([dynamic]^Component),
	}

	return c
}

radio_button_connect :: proc(component: ^Component, other_button: ^Component) {
	if component == nil do return

	if radio_button, ok := &component.variant.(RadioButton); ok {
		append(&radio_button.connected_radio_buttons, other_button)
	}
}

radio_button_set_state :: proc(component: ^Component, selected: bool) {
	if component == nil do return

	if radio_button, ok := &component.variant.(RadioButton); ok {
		radio_button.selected = selected
	}
}

radio_button_is_selected :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if radio_button, ok := &component.variant.(RadioButton); ok {
		return radio_button.selected
	}

	return false
}

radio_button_was_activated :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if radio_button, ok := component.variant.(RadioButton); ok {
		return radio_button.state == .Released && radio_button.selected
	}

	return false
}

CheckBox :: struct {
	selected: bool,
	state: SimpleButtonState,
}

make_check_box :: proc(min_size: rl.Vector2 = {18.0, 18.0}, selected: bool = false) -> ^Component {
	c := new(Component)

	c.min_size = min_size

	c.variant = CheckBox{
		selected = selected,
		state = .Idle,
	}

	return c
}

check_box_is_selected :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if check_box, ok := &component.variant.(CheckBox); ok {
		return check_box.selected
	}

	return false
}

check_box_was_activated :: proc(component: ^Component) -> bool {
	if component == nil do return false

	if check_box, ok := component.variant.(CheckBox); ok {
		return check_box.state == .Released && check_box.selected
	}

	return false
}

Label :: struct {
	text:       cstring,
	font: 		rl.Font,
	font_size:  f32,
	color:      rl.Color,
	alignment:  AnchorType,
}

make_label :: proc(text: string, font: rl.Font, font_size: f32 = 20.0, color: rl.Color = rl.BLACK, alignment: AnchorType = .Center) -> ^Component {
	c := new(Component)
	c.variant = Label{
		text      = strings.clone_to_cstring(text),
		font 	  = font,
		font_size = font_size,
		color     = color,
		alignment = alignment,
	}
	return c
}

label_set_text :: proc(component: ^Component, text: string) {
	if component == nil do return

	if label, ok := &component.variant.(Label); ok {
		delete(label.text)
		label.text = strings.clone_to_cstring(text)

		component.desired_size = {0, 0}
	}
}

label_set_color :: proc(component: ^Component, color: rl.Color) {
	if component == nil do return

	if label, ok := &component.variant.(Label); ok {
		label.color = color
	}
}

LoadingBar :: struct {
	max, current:     f32,
	color:            rl.Color,
	background_color: rl.Color,
}

make_loading_bar :: proc(current, max: f32, color: rl.Color, bg_color: rl.Color, size: rl.Vector2) -> ^Component {
	c := new(Component)
	c.desired_size = size
	c.min_size     = size
	c.variant = LoadingBar{
		current          = current,
		max              = max,
		color            = color,
		background_color = bg_color,
	}
	return c
}

loading_bar_set_color :: proc(component: ^Component, new_color: rl.Color) {
	if component == nil do return

	if loading_bar, ok := &component.variant.(LoadingBar); ok {
		loading_bar.color = new_color
	}
}

GraphValueGetter :: #type proc(data: rawptr, index: int) -> f32

Graph :: struct {
	child: ^Component,
	color_background, color_grid, color_lines: rl.Color,
	data_buffer: rawptr,
	data_count: int,
	get_value: GraphValueGetter,
	min_val, max_val: f32,
}

make_graph :: proc(min_size: rl.Vector2, child: ^Component = nil) -> ^Component {
	c := new(Component)

	c.size = min_size
	c.min_size = min_size

	c.variant = Graph{
		child = child,
		color_background   = rl.DARKGRAY,
		color_grid   = rl.Color{128.0, 128.0, 128.0, 128.0},
		color_lines   = rl.ORANGE,
	}

	return c
}

graph_set_data :: proc(component: ^Component, data_buffer: rawptr, count: int, getter: GraphValueGetter, min_v, max_v: f32) {
	if component == nil do return

	if graph, ok := &component.variant.(Graph); ok {
		graph.data_buffer = data_buffer
		graph.data_count  = count
		graph.get_value   = getter
		graph.min_val     = min_v
		graph.max_val     = max_v
	}
}

graph_set_line_color :: proc(component: ^Component, new_color: rl.Color) {
	if component == nil do return

	if graph, ok := &component.variant.(Graph); ok {
		graph.color_lines = new_color
	}
}


// --------- Compound components -----------

JobDisplay :: struct {
	root: ^Component,

	level_label: ^Component,
	name_label: ^Component,
	income_label: ^Component,
	ticks_label: ^Component,
	buyin_price_label: ^Component,
	start_button: ^Component,
	button_label: ^Component,

	progress_box: ^Component,
}

make_job_display :: proc(job: ^jobs.Job) -> JobDisplay {
	widget: JobDisplay = {}

	base_color, button_color: rl.Color

	widget.buyin_price_label = make_label("", global.font_small_italic, 18.0, rl.BLACK, .Center)
	buyin_pill := make_pill(rl.RAYWHITE, {}, widget.buyin_price_label)

	if _, ok := job.details.(jobs.BuyinJob); ok {
		base_color = rl.Color{192, 92, 92, 255}
		button_color = rl.RED
	} else {
		base_color = rl.GRAY
		button_color = rl.DARKGRAY
		buyin_pill.state = .Inactive
	}

	widget.button_label = make_label("", global.font, 24.0, rl.RAYWHITE)
	widget.start_button = make_simple_button(.OnRelease, button_color, {80.0, 0.0}, widget.button_label)

	widget.level_label = make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.name_label = make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.income_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	total_width := f32(320.0 - 32.0)
	widget.progress_box = make_box(.Horizontal, .Start, .Fill, 1)

	if job.ticks_needed > 0 {
		total_gap_width := f32(job.ticks_needed - 1) * 1.0
		segment_width := (total_width - total_gap_width) / f32(job.ticks_needed)

		for _ in 0..<job.ticks_needed {
			bar := make_loading_bar(
				0, 1.0,
				rl.YELLOW, rl.DARKGRAY,
				{segment_width, 8.0},
			)

			box_add_child(widget.progress_box, bar)
		}
	}

	widget.root = make_panel(base_color, {320.0, 120.0},
		make_margin(16, 16, 16, 16,
			make_box(.Vertical, .SpaceBetween, .Fill, 4,
				make_box(.Horizontal, .Fill, .Fill, 16,
					make_box(.Vertical, .SpaceBetween, .Fill, 4,
						widget.level_label,
						widget.name_label,
						widget.income_label,
					),
					make_box(.Vertical, .Start, .End, 4,
						widget.start_button,
						buyin_pill,
					),
				),
				widget.ticks_label,
				widget.progress_box,
			),
		),
	)

	update_job_display(&widget, job, 0.0, 1.0)

	return widget
}

update_job_display :: proc(widget: ^JobDisplay, job: ^jobs.Job, tick_timer: f32, tick_speed: f32) {
	label_set_text(widget.level_label, fmt.tprintf("%s%s", strings.repeat("◆", job.level, context.temp_allocator), strings.repeat("◇", 10 - job.level, context.temp_allocator)))
	label_set_text(widget.name_label, job.name)
	if job.is_active {
		label_set_text(widget.name_label, fmt.tprintf("%s ▶", job.name))
	} else if job.is_ready {
		label_set_text(widget.name_label, fmt.tprintf("%s ▷", job.name))
	} else {
		label_set_text(widget.name_label, job.name)
	}

	if job.income > 0.0 {
		if job.illegitimate_income > 0.0 {
			label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2), global.format_float_thousands(job.illegitimate_income, 2)))
		} else {
			label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2)))
		}
	} else {
		label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2)))
	}

	if details, ok := job.details.(jobs.BuyinJob); ok {
		label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Failure chance: %s%% / tick)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 2)))
		if details.buyin_price > 0.0 {
			if details.illegitimate_buyin_price > 0.0 {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(details.buyin_price, 2), global.format_float_thousands(details.illegitimate_buyin_price, 2)))
			} else {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $", global.format_float_thousands(details.buyin_price, 2)))
			}
		} else {
			label_set_text(widget.buyin_price_label, fmt.tprintf("%s ₴", global.format_float_thousands(details.illegitimate_buyin_price, 2)))
		}
	} else {
		label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	label_set_text(widget.button_label, job.is_ready || job.is_active ? "Stop" : "Start")

	if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
		for child, i in box.children {
			if bar, is_bar := &child.variant.(LoadingBar); is_bar {
				if !job.is_active {
					 bar.current = 0.0
				} else if i < job.ticks_current {
					bar.current = 1.0
					bar.max = 1.0
				} else if i == job.ticks_current {
					bar.current = tick_timer
					bar.max = tick_speed
				} else {
					bar.current = 0.0
				}
			}
		}
	}
}

CrewMemberDisplay :: struct {
	root:           ^Component,

	nickname_label: ^Component,
	salary_label:   ^Component,
	job_name_label: ^Component,
	income_label:   ^Component,
	ticks_label:    ^Component,
	progress_box:   ^Component,
}

make_crew_member_display :: proc(cm: ^crew.CrewMember) -> CrewMemberDisplay {
	widget: CrewMemberDisplay = {}

	base_color: rl.Color
	#partial switch details in cm.default_job.details {
	case jobs.BuyinJob:
		base_color = rl.Color{192, 92, 92, 255}
	case:
		base_color = rl.GRAY
	}

	widget.nickname_label = make_label("", global.font, 24.0, rl.RAYWHITE, .Left)

	widget.salary_label = make_label("", global.font_small, 18.0, rl.BLACK, .Right)

	widget.job_name_label = make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.income_label   = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label    = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)

	usable_width := f32(320.0 - 32.0)

	widget.progress_box = make_box(.Horizontal, .Start, .Fill, 1)

	ticks_needed := cm.default_job.ticks_needed
	if ticks_needed > 0 {
		total_gaps := f32(ticks_needed - 1) * 1.0
		segment_width := (usable_width - total_gaps) / f32(ticks_needed)

		for _ in 0..<ticks_needed {
			bar := make_loading_bar(
				0.0, 1.0,
				rl.Color{92, 92, 192, 255},
				rl.DARKGRAY,
				{segment_width, 8.0},
			)
			box_add_child(widget.progress_box, bar)
		}
	}

	widget.root = make_panel(base_color, {320.0, 120.0},
		make_margin(16, 16, 16, 16,
			make_box(.Vertical, .SpaceBetween, .Fill, 4,
				make_box(.Horizontal, .SpaceBetween, .Center, 0,
					widget.nickname_label,
					make_pill(rl.RAYWHITE, {},
						widget.salary_label,
					),
				),
				make_box(.Vertical, .Start, .Fill, 2,
					widget.job_name_label,
					widget.income_label,
					widget.ticks_label,
				),
				widget.progress_box,
			),
		),
	)

	update_crew_member_display(&widget, cm, 0.0, 1.0)

	return widget
}

update_crew_member_display :: proc(widget: ^CrewMemberDisplay, cm: ^crew.CrewMember, tick_timer: f32, tick_speed: f32) {
	label_set_text(widget.nickname_label, fmt.tprintf("'%s'", cm.nickname))

	if cm.base_salary > 0.0 {
		if cm.base_salary_illegitimate > 0.0 {
			label_set_text(widget.salary_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(cm.base_salary, 2), global.format_float_thousands(cm.base_salary_illegitimate, 2)))
		} else {
			label_set_text(widget.salary_label, fmt.tprintf("%s $", global.format_float_thousands(cm.base_salary, 2)))
		}
	} else {
		label_set_text(widget.salary_label, fmt.tprintf("%s ₴", global.format_float_thousands(cm.base_salary_illegitimate, 2)))
	}

	job_name := cm.default_job.name
	if cm.default_job.is_active {
		label_set_text(widget.job_name_label, fmt.tprintf("%s ▶", job_name))
	} else if cm.default_job.is_ready {
		label_set_text(widget.job_name_label, fmt.tprintf("%s ▷", job_name))
	} else {
		label_set_text(widget.job_name_label, job_name)
	}

	job := &cm.default_job
	if job.income > 0.0 {
		if job.illegitimate_income > 0.0 {
			label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2), global.format_float_thousands(job.illegitimate_income, 2)))
		} else {
			label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2)))
		}
	} else {
		label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2)))
	}

	#partial switch details in job.details {
	case jobs.BuyinJob:
		 label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Fail: %s%%)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 1)))
	case:
		 label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
		for child, i in box.children {
			if bar, is_bar := &child.variant.(LoadingBar); is_bar {
				if !job.is_active {
					bar.current = 0.0
				} else if i < job.ticks_current {
					bar.current = 1.0
					bar.max = 1.0
				} else if i == job.ticks_current {
					bar.current = tick_timer
					bar.max = tick_speed
				} else {
					bar.current = 0.0
				}
			}
		}
	}
}

StockWindow :: struct {
	root: ^Component,

	selected_id: stocks.CompanyID,
	company_list: [dynamic]stocks.CompanyID,
	stock_price_labels: [dynamic]^Component,

	stock_list_box: ^Component,

	detail_root:    ^Component,
    name_label:     ^Component,
    price_label:    ^Component,
    available_label:    ^Component,
    owned_label:    ^Component,
    profit_loss_label:    ^Component,
    buy_button:    ^Component,
    sell_button:    ^Component,
}

make_stock_window :: proc(market: ^stocks.StockMarket) -> StockWindow {
	widget: StockWindow = {}

	widget.company_list = make([dynamic]stocks.CompanyID)
	for id, _ in market.companies {
        append(&widget.company_list, id)
    }
    slice.sort(widget.company_list[:])

	widget.selected_id = -1

	base_color := rl.GRAY

	widget.stock_list_box = make_box(.Vertical, .Start, .Fill, 4)

	widget.stock_price_labels = make([dynamic]^Component)
    for id in widget.company_list {
    	company := &market.companies[id]
    	stock_price_label := make_label("-", global.font_small, 18, rl.BLACK, .Right)
    	append(&widget.stock_price_labels, stock_price_label)
        box_add_child(widget.stock_list_box,
            make_simple_button(.OnRelease, rl.DARKGRAY, {},
            	make_box(.Horizontal, .SpaceBetween, .Center, 12,
            		make_box(.Horizontal, .Start, .Center, 12,
            			make_pill(rl.GRAY, {60.0, 0.0},
	            			make_label(fmt.tprintf("%s", company.ticker_symbol), global.font_small_italic, 18, rl.BLACK, .Center),
	        			),
	        			make_label(fmt.tprintf("%s", company.name), global.font, 24, rl.BLACK, .Left),
        			),
            		stock_price_label,
        		),
        	),
        )
    }

    widget.name_label  = make_label("-", global.font, 24, rl.BLACK)
    widget.price_label = make_label("-", global.font_small, 18, rl.BLACK)
    widget.available_label = make_label("-", global.font_small, 18, rl.BLACK)
    widget.owned_label = make_label("-", global.font_small, 18, rl.BLACK)
    widget.profit_loss_label = make_label("-", global.font_small, 18, rl.BLACK)

    widget.buy_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
    	make_label("Buy 1", global.font, 24, rl.BLACK),
	)
	widget.sell_button = make_simple_button(.OnRelease, rl.GRAY, {100.0, 0.0},
    	make_label("Sell 1", global.font, 24, rl.BLACK),
	)

    widget.detail_root = make_panel(rl.DARKGRAY, {0, 200},
        make_margin(8, 8, 8, 8,
        	make_box(.Vertical, .Start, .Start, 10,
	            widget.name_label,
	            widget.price_label,
    	        widget.available_label,
    	        make_box(.Horizontal, .Start, .Fill, 8,
    	        	widget.owned_label,
    	        	widget.profit_loss_label,
	        	),
    	        make_box(.Horizontal, .Start, .Fill, 8,
    	        	widget.buy_button,
    	        	widget.sell_button,
	        	),
        	),
    	),
    )

    stock_panel := make_anchor(.Center,
        make_panel(base_color, {},
    		make_margin(16, 16, 16, 16,
    			make_box(.Vertical, .Start, .Fill, 10,
	                make_label("Stock Market", global.font_large, 28, rl.WHITE),
	                make_scroll_container({600.0, 400.0}, widget.stock_list_box),
	                widget.detail_root,
	            ),
			),
    	),
    )

	widget.root = stock_panel

	return widget
}

update_stock_window :: proc(window: ^StockWindow, market: ^stocks.StockMarket, portfolio: ^stocks.StockPortfolio) {
	for id, i in window.company_list {
		company := &market.companies[id]
		label_set_text(window.stock_price_labels[i], fmt.tprintf("$%.2f", company.current_price))
	}

    if company, ok := &market.companies[window.selected_id]; ok {
        window.detail_root.state = .Active

        stock_info := &portfolio.stocks[window.selected_id]
        available_stocks := stocks.get_available_shares(company, stock_info)

        label_set_text(window.name_label, company.name)
        label_set_text(window.price_label, fmt.tprintf("$%.2f per share", company.current_price))
        label_set_text(window.available_label, fmt.tprintf("%s shares available", global.format_int_thousands(available_stocks)))
        if stock_info.quantity_owned > 0 {
        	window.profit_loss_label.state = .Active
        	label_set_text(window.owned_label,
        		fmt.tprintf(
        			"You own %s shares @ %s",
        			global.format_int_thousands(stock_info.quantity_owned),
        			global.format_float_thousands(stock_info.average_cost, 2),
    			),
    		)
    		unrealized_profit_loss := (company.current_price / stock_info.average_cost) - 1.0
    		if global.is_approx_zero(unrealized_profit_loss) {
    			label_set_color(window.profit_loss_label, rl.BLACK)
    			label_set_text(window.profit_loss_label, "[0.00 %]")
    		} else if unrealized_profit_loss < 0.0 {
    			label_set_color(window.profit_loss_label, rl.RED)
    			label_set_text(window.profit_loss_label, fmt.tprintf("[%s %%]", global.format_float_thousands(unrealized_profit_loss * 100.0, 2)))
    		} else if unrealized_profit_loss > 0.0 {
    			label_set_color(window.profit_loss_label, rl.GREEN)
    			label_set_text(window.profit_loss_label, fmt.tprintf("[+%s %%]", global.format_float_thousands(unrealized_profit_loss * 100.0, 2)))
    		}
        } else {
        	label_set_text(window.owned_label, "You own no shares")
        	window.profit_loss_label.state = .Hidden
        }
    } else {
        window.detail_root.state = .Hidden
    }
}

// -----------------------------------------

update_components_recursive :: proc(component: ^Component, base_rect: rl.Rectangle) {
	get_desired_size(component)
	arrange_components(component, base_rect)
}

@(private="file")
get_desired_size :: proc(component: ^Component) -> rl.Vector2 {
	if component == nil || component.state == .Inactive do return {}

	desired_size: rl.Vector2

	switch v in component.variant {
	case StackContainer:
		for child in v.children {
			child_size := get_desired_size(child)
			desired_size.x = max(desired_size.x, child_size.x)
			desired_size.y = max(desired_size.y, child_size.y)
		}
	case AnchorContainer:
		desired_size = get_desired_size(v.child)
	case BoxContainer:
		count := len(v.children)
		for child, i in v.children {
			child_desired_size := get_desired_size(child)
			if v.direction == .Vertical {
				desired_size.x = max(desired_size.x, child_desired_size.x)
				desired_size.y += child_desired_size.y
				if i < count - 1 {
					desired_size.y += f32(v.gap)
				}
			} else {
				desired_size.x += child_desired_size.x
				if i < count - 1 {
					desired_size.x += f32(v.gap)
				}
				desired_size.y = max(desired_size.y, child_desired_size.y)
			}
		}
	case MarginContainer:
		desired_size = get_desired_size(v.child)
		desired_size.x += f32(v.margin_left + v.margin_right)
		desired_size.y += f32(v.margin_top + v.margin_bottom)
	case ScrollContainer:
		if v.child != nil {
            _ = get_desired_size(v.child)
        }
		desired_size = component.min_size
	case Panel:
		desired_size = get_desired_size(v.child)
		desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case Pill:
		child_desired_size := get_desired_size(v.child) + {0.0, 2.0}
		desired_size.x = child_desired_size.x + child_desired_size.y
		desired_size.y = child_desired_size.y
		desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case SimpleButton:
		child_desired_size := get_desired_size(v.child)
		desired_size.x = child_desired_size.x + (v.padding * 2)
		desired_size.y = child_desired_size.y + (v.padding * 2)
		desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case Label:
		desired_size = rl.MeasureTextEx(v.font, v.text, v.font_size, 2.0)
	case RadioButton, CheckBox, LoadingBar:
		desired_size = component.min_size
	case Graph:
		desired_size = get_desired_size(v.child)
		desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	}

	component.desired_size = desired_size

	return desired_size
}

@(private="file")
arrange_components :: proc(component: ^Component, actual_rect: rl.Rectangle) {
	if component == nil || component.state == .Inactive do return

	component.position = {actual_rect.x, actual_rect.y}
	component.size     = {actual_rect.width, actual_rect.height}

	switch &v in component.variant {
	case StackContainer:
		for child in v.children {
			arrange_components(child, actual_rect)
		}
	case AnchorContainer:
		if v.child != nil {
			child_w := v.child.desired_size.x
			child_h := v.child.desired_size.y

			pos: rl.Vector2

			switch v.type {
			case .TopLeft, .Left, .BottomLeft:
				pos.x = actual_rect.x
			case .Top, .Center, .Bottom:
				pos.x = actual_rect.x + (actual_rect.width - child_w) * 0.5
			case .TopRight, .Right, .BottomRight:
				pos.x = actual_rect.x + actual_rect.width - child_w
			}

			switch v.type {
			case .TopLeft, .Top, .TopRight:
				pos.y = actual_rect.y
			case .Left, .Center, .Right:
				pos.y = actual_rect.y + (actual_rect.height - child_h) * 0.5
			case .BottomLeft, .Bottom, .BottomRight:
				pos.y = actual_rect.y + actual_rect.height - child_h
			}

			child_rect := rl.Rectangle{pos.x, pos.y, child_w, child_h}
			arrange_components(v.child, child_rect)
		}
	case BoxContainer:
		total_content_size: f32 = 0
		valid_children := 0

		for child in v.children {
			if child == nil do continue
			valid_children += 1

			if v.direction == .Vertical {
				total_content_size += child.desired_size.y
			} else {
				total_content_size += child.desired_size.x
			}
		}

		current_gap := f32(v.gap)

		available_space := v.direction == .Vertical ? actual_rect.height : actual_rect.width

		total_gap_space := f32(max(0, valid_children - 1)) * current_gap
		total_used_space := total_content_size + total_gap_space

		free_space := available_space - total_used_space

		start_offset: f32 = 0.0

		child_forced_size: f32 = 0.0

		switch v.main_alignment {
		case .Start:
			start_offset = 0.0

		case .Center:
			start_offset = free_space * 0.5

		case .End:
			start_offset = free_space

		case .Fill:
			start_offset = 0.0
			remaining_space := available_space - total_used_space

			if valid_children > 0 && remaining_space > 0 {
				child_forced_size = remaining_space / f32(valid_children)
			} else {
				child_forced_size = 0.0
			}

		case .SpaceBetween:
			start_offset = 0.0
			if valid_children > 1 {
				current_gap = (available_space - total_content_size) / f32(valid_children - 1)
			}

		case .SpaceEvenly:
			if valid_children > 0 {
				gap_size := (available_space - total_content_size) / f32(valid_children + 1)
				current_gap = gap_size
				start_offset = gap_size
			}
		}

		cursor := rl.Vector2{actual_rect.x, actual_rect.y}

		if v.direction == .Vertical {
			cursor.y += start_offset
		} else {
			cursor.x += start_offset
		}

		for child in v.children {
			if child == nil do continue

			child_rect: rl.Rectangle

			if v.direction == .Vertical {
				if v.main_alignment == .Fill {
					child_rect.height = child.desired_size.y + child_forced_size
				} else {
					child_rect.height = child.desired_size.y
				}

				switch v.cross_alignment {
				case .Start:
					child_rect.width = child.desired_size.x
					child_rect.x     = actual_rect.x
				case .Center:
					child_rect.width = child.desired_size.x
					child_rect.x     = actual_rect.x + (actual_rect.width - child_rect.width) * 0.5
				case .End:
					child_rect.width = child.desired_size.x
					child_rect.x     = actual_rect.x + (actual_rect.width - child_rect.width)
				case .Fill:
					child_rect.width = actual_rect.width
					child_rect.x     = actual_rect.x
				}

				child_rect.y = cursor.y

				cursor.y += child_rect.height + current_gap

			} else {
				if v.main_alignment == .Fill {
					child_rect.width = child.desired_size.x + child_forced_size
				} else {
					child_rect.width = child.desired_size.x
				}

				switch v.cross_alignment {
				case .Start:
					child_rect.height = child.desired_size.y
					child_rect.y      = actual_rect.y
				case .Center:
					child_rect.height = child.desired_size.y
					child_rect.y      = actual_rect.y + (actual_rect.height - child_rect.height) * 0.5
				case .End:
					child_rect.height = child.desired_size.y
					child_rect.y      = actual_rect.y + (actual_rect.height - child_rect.height)
				case .Fill:
					child_rect.height = actual_rect.height
					child_rect.y      = actual_rect.y
				}

				child_rect.x = cursor.x

				cursor.x += child_rect.width + current_gap
			}

			arrange_components(child, child_rect)
		}

	case MarginContainer:
		if v.child != nil {
			child_rect := rl.Rectangle{
				x      = actual_rect.x + f32(v.margin_left),
				y      = actual_rect.y + f32(v.margin_top),
				width  = actual_rect.width - f32(v.margin_left + v.margin_right),
				height = actual_rect.height - f32(v.margin_top + v.margin_bottom),
			}
			arrange_components(v.child, child_rect)
		}

	case ScrollContainer:
		if v.child != nil {
            v.viewport_height = actual_rect.height
            v.content_height  = v.child.desired_size.y
            v.scrollable_range = max(0.0, v.content_height - v.viewport_height)

            v.scroll_y = math.clamp(v.scroll_y, 0.0, v.scrollable_range)

            child_full_rect := rl.Rectangle{
                actual_rect.x,
                actual_rect.y - v.scroll_y,
                actual_rect.width - (v.content_height > v.viewport_height ? 16.0 : 0.0),
                v.child.desired_size.y,
            }
            arrange_components(v.child, child_full_rect)
        }

	case Panel:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case Pill:
		if v.child != nil {
			child_rect := rl.Rectangle{
				x      = actual_rect.x + actual_rect.height * 0.5,
				y      = actual_rect.y,
				width  = actual_rect.width - actual_rect.height,
				height = actual_rect.height,
			}
			arrange_components(v.child, child_rect)
		}

	case SimpleButton:
		if v.child != nil {
			padding_x := v.padding * 2
            padding_y := v.padding * 2

			safe_width  := max(0.0, actual_rect.width - padding_x)
            safe_height := max(0.0, actual_rect.height - padding_y)

			child_rect := rl.Rectangle{
                x      = actual_rect.x + v.padding,
                y      = actual_rect.y + v.padding,
                width  = safe_width,
                height = safe_height,
            }

			arrange_components(v.child, child_rect)
		}

	case Graph:
		if v.child != nil {
			arrange_components(v.child, actual_rect)
		}

	case Label, LoadingBar, RadioButton, CheckBox:
	}
}

handle_input_recursive :: proc(component: ^Component, input_data: ^input.RawInput) -> bool {
	if component == nil || component.state != .Active do return false

	captured := false
	mouse_pos := input_data.mouse_position
	rect := rl.Rectangle{
		component.position.x, component.position.y,
		component.size.x,     component.size.y,
	}

	switch &v in component.variant {
	case StackContainer:
		#reverse for child in v.children {
			if handle_input_recursive(child, input_data) do captured = true
		}
	case AnchorContainer:
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case BoxContainer:
		for child in v.children {
			if handle_input_recursive(child, input_data) do captured = true
		}

	case MarginContainer:
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case ScrollContainer:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)

		real_mouse_pos := input_data.mouse_position

		if !is_hovered {
			input_data.mouse_position = {-99999, -99999}
		}

	    if v.child != nil {
	        if handle_input_recursive(v.child, input_data) do captured = true
	    }

	    input_data.mouse_position = real_mouse_pos

	    if is_hovered {
	        if v.scrollable_range > 0.0 && input_data.mouse_wheel_movement != 0.0 {
	        	captured = true
	            scroll_delta := input_data.mouse_wheel_movement * 20.0
	            v.scroll_y = math.clamp(v.scroll_y - scroll_delta, 0.0, v.scrollable_range)
	        }
	    }

	case Panel:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case Pill:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case SimpleButton:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
		mouse_button_just_pressed := input.is_mouse_button_pressed_this_frame(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if is_hovered {
				if mouse_button_just_pressed {
					v.state = .Pressed
				} else if !mouse_button_pressed && v.state == .Pressed {
					v.state = .Released
				} else if !mouse_button_pressed {
					v.state = .Hovered
				}
			} else {
				v.state = .Idle
			}
		}

		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}

	case RadioButton:
		center := rl.Vector2{rect.x + rect.width * 0.5, rect.y + rect.height * 0.5}
		is_hovered := rl.Vector2Distance(center, mouse_pos) <= rect.width * 0.5
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)
		mouse_button_just_pressed := input.is_mouse_button_pressed_this_frame(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if is_hovered {
				if mouse_button_just_pressed {
					v.state = .Pressed
				} else if !mouse_button_pressed && v.state == .Pressed {
					if !v.selected {
						v.state = .Released
						v.selected = true
						for other_button in v.connected_radio_buttons {
							radio_button_set_state(other_button, false)
						}
					}
				} else if !mouse_button_pressed {
					v.state = .Hovered
				}
			} else {
				v.state = .Idle
			}
		}

	case CheckBox:
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)

		captured = is_hovered

		if v.state != .Disabled {
			if v.state == .Pressed {
				if is_hovered && !mouse_button_pressed {
					v.state = .Released

					v.selected = !v.selected

				} else if !is_hovered && !mouse_button_pressed {
					v.state = .Idle
				}
			} else {
				if is_hovered {
					if mouse_button_pressed {
						v.state = .Pressed
					} else {
						v.state = .Hovered
					}
				} else {
					v.state = .Idle
				}
			}
		}

	case Label, LoadingBar:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)

	case Graph:
		captured = rl.CheckCollisionPointRec(mouse_pos, rect)
		if v.child != nil {
			if handle_input_recursive(v.child, input_data) do captured = true
		}
	}

	return captured
}

draw_components_recursive :: proc(component: ^Component, debug: bool = false) {
	if component == nil || component.state != .Active do return

	switch v in component.variant {
	case StackContainer:
		for child in v.children {
			draw_components_recursive(child, debug)
		}
	case AnchorContainer:
		draw_components_recursive(v.child, debug)
	case BoxContainer:
		for child in v.children {
			draw_components_recursive(child, debug)
		}
	case MarginContainer:
		draw_components_recursive(v.child, debug)
	case ScrollContainer:
		if v.child != nil {
			if v.scrollable_range > 0.0 {
				rl.DrawCircleV({component.position.x + component.size.x - 7.0, component.position.y + 7.0}, 7.0, rl.DARKGRAY)
				rl.DrawCircleV({component.position.x + component.size.x - 7.0, component.position.y + component.size.y - 7.0}, 7.0, rl.DARKGRAY)

		        rl.DrawRectangleV(
		        	{component.position.x + component.size.x - 14.0, component.position.y + 7.0},
		        	{14.0, component.size.y - 14.0},
		        	rl.DARKGRAY,
	        	)

		        scroll_amount := v.scroll_y / v.scrollable_range

	        	scroll_knob_length := v.scrollable_range
	        	scroll_knob_start_bottom := v.viewport_height - v.scrollable_range

	        	scroll_knob_start := scroll_knob_start_bottom * scroll_amount
	        	scroll_know_end := scroll_knob_start + scroll_knob_length

	        	rl.DrawCircleV({component.position.x + component.size.x - 7.0, component.position.y + scroll_knob_start + 7.0}, 7.0, rl.RAYWHITE)
	        	rl.DrawCircleV({component.position.x + component.size.x - 7.0, component.position.y + scroll_know_end - 7.0}, 7.0, rl.RAYWHITE)
	        	rl.DrawRectangleV({component.position.x + component.size.x - 14.0, component.position.y + scroll_knob_start + 7.0}, {14.0, scroll_knob_length - 14.0}, rl.RAYWHITE)
				}

	        rl.BeginScissorMode(
	            i32(component.position.x),
	            i32(component.position.y),
	            i32(component.size.x),
	            i32(component.size.y),
	        )
	        draw_components_recursive(v.child, debug)

	        rl.EndScissorMode()
	    }
	case Panel:
		rl.DrawRectangleV(component.position, component.size, v.color)
		draw_components_recursive(v.child, debug)
	case Pill:
		offset := component.size.y * 0.5
		rl.DrawCircleV(component.position + {offset, offset}, offset, v.color)
		rl.DrawCircleV(component.position + {component.size.x - offset, offset}, offset, v.color)
		rl.DrawRectangleV(component.position + {offset, 0.0}, {component.size.x - component.size.y, component.size.y}, v.color)
		draw_components_recursive(v.child, debug)
	case SimpleButton:
		bg_color: rl.Color
		switch v.state {
		case .Idle:     bg_color = v.color_default
		case .Hovered:  bg_color = v.color_hovered
		case .Pressed:  bg_color = v.color_pressed
		case .Released: bg_color = v.color_hovered
		case .Disabled: bg_color = rl.GRAY
		}

		rl.DrawRectangleV(component.position, component.size, bg_color)

		if v.state == .Pressed {
			rl.DrawRectangleLinesEx(rl.Rectangle{
				component.position.x, component.position.y,
				component.size.x, component.size.y,
			}, 2.0, rl.ColorBrightness(bg_color, -0.3))
		}

		draw_components_recursive(v.child, debug)
	case RadioButton:
		circle_texture := textures.ui_textures[textures.UiTextureId.Circle]
		ring_texture := textures.ui_textures[textures.UiTextureId.Ring]

		ring_color := rl.SKYBLUE
		dot_color  := rl.DARKBLUE
		background_color := rl.BLACK
		foreground_color := rl.RAYWHITE

		source := rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
		dest   := rl.Rectangle{
			component.position.x, component.position.y,
			component.size.x, component.size.y,
		}
		rl.DrawTexturePro(circle_texture, source, dest, {}, 0, background_color)

		source = rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
		dest   = rl.Rectangle{
			component.position.x + 1, component.position.y + 1,
			component.size.x - 2, component.size.y - 2,
		}
		rl.DrawTexturePro(circle_texture, source, dest, {}, 0, foreground_color)

		if v.selected {
			source = rl.Rectangle{0, 0, f32(circle_texture.width), f32(circle_texture.height)}
			dest   = rl.Rectangle{
				component.position.x + 5.0, component.position.y + 5.0,
				component.size.x - 10.0, component.size.y - 10.0,
			}
			rl.DrawTexturePro(circle_texture, source, dest, {}, 0, dot_color)
		}
		if v.state == .Hovered || v.state == .Pressed {
			source = rl.Rectangle{0, 0, f32(ring_texture.width), f32(ring_texture.height)}
			dest   = rl.Rectangle{
				component.position.x + 1, component.position.y + 1,
				component.size.x - 2, component.size.y - 2,
			}
			rl.DrawTexturePro(ring_texture, source, dest, {}, 0, ring_color)
		}
	case CheckBox:
		square_texture := textures.ui_textures[textures.UiTextureId.Square]
		box_texture := textures.ui_textures[textures.UiTextureId.Box]
		tick_texture := textures.ui_textures[textures.UiTextureId.Tick]

		box_color := rl.SKYBLUE
		tick_color  := rl.DARKBLUE
		background_color := rl.BLACK
		foreground_color := rl.RAYWHITE

		source := rl.Rectangle{0, 0, f32(square_texture.width), f32(square_texture.height)}
		dest   := rl.Rectangle{
			component.position.x, component.position.y,
			component.size.x, component.size.y,
		}
		rl.DrawTexturePro(square_texture, source, dest, {}, 0, background_color)

		source = rl.Rectangle{0, 0, f32(square_texture.width), f32(square_texture.height)}
		dest   = rl.Rectangle{
			component.position.x + 1, component.position.y + 1,
			component.size.x - 2, component.size.y - 2,
		}
		rl.DrawTexturePro(square_texture, source, dest, {}, 0, foreground_color)

		if v.selected {
			source = rl.Rectangle{0, 0, f32(tick_texture.width), f32(tick_texture.height)}
			dest   = rl.Rectangle{
				component.position.x + 1, component.position.y + 1,
				component.size.x - 2, component.size.y - 2,
			}
			rl.DrawTexturePro(tick_texture, source, dest, {}, 0, tick_color)
		}
		if v.state == .Hovered || v.state == .Pressed {
			source = rl.Rectangle{0, 0, f32(box_texture.width), f32(box_texture.height)}
			dest   = rl.Rectangle{
				component.position.x + 1, component.position.y + 1,
				component.size.x - 2, component.size.y - 2,
			}
			rl.DrawTexturePro(box_texture, source, dest, {}, 0, box_color)
		}
	case Label:
		text_dims := rl.MeasureTextEx(v.font, v.text, v.font_size, 2.0)

		pos := component.position

		#partial switch v.alignment {
		case .Top, .Center, .Bottom:
			 pos.x += (component.size.x - text_dims.x) * 0.5
		case .TopRight, .Right, .BottomRight:
			 pos.x += (component.size.x - text_dims.x)
		case:
		}

		#partial switch v.alignment {
		case .Left, .Center, .Right:
			 pos.y += (component.size.y - text_dims.y) * 0.5
		case .BottomLeft, .Bottom, .BottomRight:
			 pos.y += (component.size.y - text_dims.y)
		case:
		}

		rl.DrawTextEx(
			v.font,
			v.text,
			pos,
			v.font_size,
			2.0,
			v.color,
		)
	case LoadingBar:
		rl.DrawRectangleV(component.position, component.size, v.background_color)

		ratio := math.clamp(v.current / max(v.max, 0.0001), 0.0, 1.0)

		fill_width := component.size.x * ratio
		rl.DrawRectangleV(component.position, {fill_width, component.size.y}, v.color)
	case Graph:
		rl.DrawRectangleV(component.position, component.size, v.color_background)
		range := v.max_val - v.min_val

		point_distance := component.size.x / f32(v.data_count - 1)
		for i in 0..<v.data_count {
			rl.DrawLineV(
				{component.position.x + f32(i) * point_distance, component.position.y},
				{component.position.x + f32(i) * point_distance, component.position.y + component.size.y},
				v.color_grid)

			val := range == 0.0 ? 0.5 : 1.0 - (v.get_value(v.data_buffer, i) - v.min_val) / range

			new_point := rl.Vector2{component.position.x + f32(i) * point_distance, component.position.y + val * component.size.y}

			if i > 0 {
				val_prev := range == 0.0 ? 0.5 : 1.0 - (v.get_value(v.data_buffer, i - 1) - v.min_val) / range
				rl.DrawLineV({component.position.x + f32(i - 1) * point_distance, component.position.y + val_prev * component.size.y}, new_point, v.color_lines)
			}
			rl.DrawCircleV(new_point, 2.0, v.color_lines)
		}
		draw_components_recursive(v.child, debug)
	}

	if debug {
		rl.DrawRectangleLinesEx(rl.Rectangle{component.position.x, component.position.y, component.size.x, component.size.y}, 2.0, rl.BLACK)
		//rl.DrawRectangleLinesEx(rl.Rectangle{component.position.x, component.position.y, component.desired_size.x, component.desired_size.y}, 2.0, rl.BLUE)
	}
}

destroy_components_recursive :: proc(component: ^Component) {
	if component == nil do return

	switch v in component.variant {
	case StackContainer:
		for child in v.children {
			destroy_components_recursive(child)
		}
		delete(v.children)
	case AnchorContainer:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing AnchorContainer!")
	case BoxContainer:
		for child in v.children {
			destroy_components_recursive(child)
		}
		delete(v.children)
		//fmt.println("Freeing BoxContainer!")
	case MarginContainer:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing MarginContainer!")
	case ScrollContainer:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing ScrollContainer!")
	case Panel:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing Panel!")
	case Pill:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing Pill!")
	case SimpleButton:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing SimpleButton!")
	case RadioButton:
		delete(v.connected_radio_buttons)
		//fmt.println("Freeing RadioButton!")
	case CheckBox:
		//fmt.println("Freeing CheckBox!")
	case Label:
		delete(v.text)
		//fmt.println("Freeing Label!")
	case LoadingBar:
		//fmt.println("Freeing LoadingBar!")
	case Graph:
		destroy_components_recursive(v.child)
		//fmt.println("Freeing Graph!")
	}
	free(component)
}
