-- Ki charging.
return {
	charge_percent_per_second = 18,  -- % of max Ki per second
	charge_percent_per_control = 0.4,-- extra %/s per Ki Control point
	charge_move_speed = 0.3,         -- movement multiplier while charging
	-- After reaching max Ki, the charge key must be released before a new charge.
	interrupt_lockout = 0.6,         -- seconds unable to charge after being hit
}
