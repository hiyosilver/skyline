package ui

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:strings"
import "../crew"
import "../global"
import "../input"
import "../jobs"

Base :: struct {
	position, size: rl.Vector2,
}

Component :: struct {
	position, size, min_size, desired_size: rl.Vector2,
	variant: ComponentVariant,
}

ComponentVariant :: union {
	StackContainer,
	AnchorContainer,
	BoxContainer,
	MarginContainer,
	Panel,
	Pill,
	SimpleButton,
	Label,
	LoadingBarAlt,
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
	on_click: proc(),
}

make_simple_button :: proc(click_type: SimpleButtonClickType, color: rl.Color, min_size: rl.Vector2, on_click: proc(), child: ^Component = nil) -> ^Component {
	c := new(Component)
    
    c.min_size = min_size
    
    c.variant = SimpleButton{
        state = .Idle,
        click_type = click_type,
        color_default = color,
        color_hovered = rl.ColorBrightness(color, 0.2),
        color_pressed = rl.ColorBrightness(color, -0.2),
        padding = 4.0,
        on_click = on_click,
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

Label :: struct {
    text:       string,
    font: 		rl.Font,
    font_size:  f32,
    color:      rl.Color,
    alignment:  AnchorType,
}

make_label :: proc(text: string, font: rl.Font, font_size: f32 = 20.0, color: rl.Color = rl.BLACK, alignment: AnchorType = .Center) -> ^Component {
    c := new(Component)
    c.variant = Label{
        text      = strings.clone(text),
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
        label.text = strings.clone(text)
        
        component.desired_size = {0, 0} 
    }
}

LoadingBarAlt :: struct {
    max, current:     f32,
    color:            rl.Color,
    background_color: rl.Color,
}

make_loading_bar :: proc(current, max: f32, color: rl.Color, bg_color: rl.Color, size: rl.Vector2) -> ^Component {
    c := new(Component)
    c.desired_size = size
    c.min_size     = size
    c.variant = LoadingBarAlt{
        current          = current,
        max              = max,
        color            = color,
        background_color = bg_color,
    }
    return c
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

	if _, ok := job.details.(jobs.BuyinJob); ok {
		base_color = rl.Color{192, 92, 92, 255}
		button_color = rl.RED
	} else {
		base_color = rl.GRAY
		button_color = rl.DARKGRAY
	}

	widget.button_label = make_label("", global.font, 24.0, rl.RAYWHITE)
	widget.start_button = make_simple_button(.OnRelease, button_color, {80.0, 0.0}, proc(){}, widget.button_label)

	widget.level_label = make_label("", global.font_small, 18.0, rl.RAYWHITE, .Left)
	widget.name_label = make_label("", global.font, 24.0, rl.RAYWHITE, .Left)
	widget.income_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.ticks_label = make_label("", global.font_small_italic, 18.0, rl.RAYWHITE, .Left)
	widget.buyin_price_label = make_label("", global.font_small_italic, 18.0, rl.BLACK, .Center)

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
						make_pill(rl.RAYWHITE, {},
							widget.buyin_price_label,
						),
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
    label_set_text(widget.level_label, fmt.tprintf("%s%s", strings.repeat("◆", job.level), strings.repeat("◇", 10 - job.level)))
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
			label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2, ',', '.'), global.format_float_thousands(job.illegitimate_income, 2, ',', '.')))
		} else {
			label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2, ',', '.')))
		}
	} else {
		label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2, ',', '.')))
	}

	if details, ok := job.details.(jobs.BuyinJob); ok {
		label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Failure chance: %s%% / tick)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 2, ',', '.')))
		if details.buyin_price > 0.0 {
			if details.illegitimate_buyin_price > 0.0 {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(details.buyin_price, 2, ',', '.'), global.format_float_thousands(details.illegitimate_buyin_price, 2, ',', '.')))
			} else {
				label_set_text(widget.buyin_price_label, fmt.tprintf("%s $", global.format_float_thousands(details.buyin_price, 2, ',', '.')))
			}
		} else {
			label_set_text(widget.buyin_price_label, fmt.tprintf("%s ₴", global.format_float_thousands(details.illegitimate_buyin_price, 2, ',', '.')))
		}
	} else {
    	label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
	}

	label_set_text(widget.button_label, job.is_ready || job.is_active ? "Stop" : "Start")

	if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
        for child, i in box.children {
            if bar, is_bar := &child.variant.(LoadingBarAlt); is_bar {
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
    
    // Handles for updates
    nickname_label: ^Component,
    salary_label:   ^Component,
    job_name_label: ^Component,
    income_label:   ^Component,
    ticks_label:    ^Component,
    progress_box:   ^Component, // Holds the loading bars
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
            label_set_text(widget.salary_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(cm.base_salary, 2, ',', '.'), global.format_float_thousands(cm.base_salary_illegitimate, 2, ',', '.')))
        } else {
            label_set_text(widget.salary_label, fmt.tprintf("%s $", global.format_float_thousands(cm.base_salary, 2, ',', '.')))
        }
    } else {
        label_set_text(widget.salary_label, fmt.tprintf("%s ₴", global.format_float_thousands(cm.base_salary_illegitimate, 2, ',', '.')))
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
            label_set_text(widget.income_label, fmt.tprintf("%s $ + %s ₴", global.format_float_thousands(job.income, 2, ',', '.'), global.format_float_thousands(job.illegitimate_income, 2, ',', '.')))
        } else {
            label_set_text(widget.income_label, fmt.tprintf("%s $", global.format_float_thousands(job.income, 2, ',', '.')))
        }
    } else {
        label_set_text(widget.income_label, fmt.tprintf("%s ₴", global.format_float_thousands(job.illegitimate_income, 2, ',', '.')))
    }

    #partial switch details in job.details {
    case jobs.BuyinJob:
         label_set_text(widget.ticks_label, fmt.tprintf("%d ticks (Fail: %s%%)", job.ticks_needed, global.format_float_thousands(f64(details.failure_chance * 100.0), 1, ',', '.')))
    case:
         label_set_text(widget.ticks_label, fmt.tprintf("%d ticks", job.ticks_needed))
    }

    if box, ok := &widget.progress_box.variant.(BoxContainer); ok {
        for child, i in box.children {
            if bar, is_bar := &child.variant.(LoadingBarAlt); is_bar {
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

// -----------------------------------------

update_components_recursive :: proc(component: ^Component, base_rect: rl.Rectangle) {
	get_desired_size(component)
	arrange_components(component, base_rect)
}

@(private="file")
get_desired_size :: proc(component: ^Component) -> rl.Vector2 {
	if component == nil do return {}

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
	case Panel:
		desired_size = get_desired_size(v.child)
		desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case Pill:
		child_desired_size := get_desired_size(v.child)
		desired_size.x = child_desired_size.x + child_desired_size.y
        desired_size.y = child_desired_size.y
        desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case SimpleButton:
		child_desired_size := get_desired_size(v.child)
		desired_size.x = child_desired_size.x + (v.padding * 2)
        desired_size.y = child_desired_size.y + (v.padding * 2)
        desired_size = {max(component.min_size.x, desired_size.x), max(component.min_size.y, desired_size.y)}
	case Label:
    	desired_size = rl.MeasureTextEx(v.font, cstring(raw_data(v.text)), v.font_size, 2.0)
	case LoadingBarAlt:
		desired_size = component.min_size
	}

	component.desired_size = desired_size

	return desired_size
}

@(private="file")
arrange_components :: proc(component: ^Component, actual_rect: rl.Rectangle) {
    if component == nil do return

    component.position = {actual_rect.x, actual_rect.y}
    component.size     = {actual_rect.width, actual_rect.height}

    switch v in component.variant {
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
	        child_w := v.child.desired_size.x
	        child_h := v.child.desired_size.y
	        
	        child_x := actual_rect.x + (actual_rect.width  - child_w) * 0.5
	        child_y := actual_rect.y + (actual_rect.height - child_h) * 0.5
	        
	        child_rect := rl.Rectangle{child_x, child_y, child_w, child_h}
	        
	        arrange_components(v.child, child_rect)
	    }
    case Label, LoadingBarAlt:
    }
}

handle_input_recursive :: proc(component: ^Component, input_data: ^input.RawInput) -> bool {
    if component == nil do return false
    
    captured := false

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

    case Panel:
        if v.child != nil {
            if handle_input_recursive(v.child, input_data) do captured = true
        }

    case Pill:
        if v.child != nil {
            if handle_input_recursive(v.child, input_data) do captured = true
        }

    case SimpleButton:
        rect := rl.Rectangle{
            component.position.x, component.position.y,
            component.size.x,     component.size.y,
        }

        mouse_pos := input_data.mouse_position
        is_hovered := rl.CheckCollisionPointRec(mouse_pos, rect)
		mouse_button_pressed := input.is_mouse_button_held_down(.LEFT, input_data)

        captured = is_hovered

        if v.state != .Disabled {
            if v.state == .Pressed {
                if is_hovered && !mouse_button_pressed {
                    v.state = .Released
                    if v.on_click != nil do v.on_click()
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
        
        if v.child != nil {
            if handle_input_recursive(v.child, input_data) do captured = true
        }

    case Label, LoadingBarAlt:
    }

    return captured
}

draw_components_recursive :: proc(component: ^Component, debug: bool = false) {
	if component == nil do return

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
	case Label:
		text_dims := rl.MeasureTextEx(v.font, cstring(raw_data(v.text)), v.font_size, 2.0)
        
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
            cstring(raw_data(v.text)), 
            pos,
            v.font_size, 
            2.0, 
            v.color,
        )
	case LoadingBarAlt:
        rl.DrawRectangleV(component.position, component.size, v.background_color)
        
        ratio := math.clamp(v.current / max(v.max, 0.0001), 0.0, 1.0)
        
        fill_width := component.size.x * ratio
        
        rl.DrawRectangleV(component.position, {fill_width, component.size.y}, v.color)
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
		fmt.println("Freeing AnchorContainer!")
	case BoxContainer:
		for child in v.children {
			destroy_components_recursive(child)
		}
		delete(v.children)
		fmt.println("Freeing BoxContainer!")
	case MarginContainer:
		destroy_components_recursive(v.child)
		fmt.println("Freeing MarginContainer!")
	case Panel:
		destroy_components_recursive(v.child)
		fmt.println("Freeing Panel!")
	case Pill:
		destroy_components_recursive(v.child)
		fmt.println("Freeing Pill!")
	case SimpleButton:
		destroy_components_recursive(v.child)
		fmt.println("Freeing SimpleButton!")
	case Label:
		delete(v.text)
		fmt.println("Freeing Label!")
	case LoadingBarAlt:
		fmt.println("Freeing LoadingBar!")
	}
	free(component)
}
