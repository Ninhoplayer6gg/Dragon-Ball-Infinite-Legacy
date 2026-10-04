-- HUD layout in HUD pixels (the engine scales them by screen density and the
-- player's hud_scaling setting, so the HUD adapts to phones and monitors).
-- Bars sit just above the hotbar, which is clear of touchscreen controls.
return {
	bar_width = 230,
	bar_height = 14,
	small_bar_height = 8,
	gap = 6,              -- horizontal gap between the left and right columns
	bottom_offset = -96,  -- y of the main bars relative to the screen bottom
	update_interval = 0.1,
	low_hp = 0.25,        -- HP ratio that turns the bar into the warning color
	notify_time = 4,      -- seconds a notification stays on screen
	notify_max = 4,
	target_frame_time = 5,
	tip_interval = 90,    -- seconds between gameplay tips (if enabled)
	-- On touchscreens the right edge holds the control buttons; right-aligned
	-- HUD text is moved left by this many HUD pixels (about 1.7 buttons).
	touch_right_margin = 110,
}
