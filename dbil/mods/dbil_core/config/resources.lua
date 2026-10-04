-- Regeneration of HP, Ki and Stamina.
return {
	-- HP regenerates only out of combat.
	hp_regen_percent = 0.8,          -- % of max HP per second
	hp_regen_combat_delay = 8,       -- seconds after last damage dealt/taken

	ki_regen_percent = 1.0,          -- % of max Ki per second (passive)
	ki_regen_delay = 1.5,            -- seconds after spending Ki

	stamina_regen_per_second = 22,
	stamina_regen_delay = 0.8,       -- seconds after spending Stamina

	tick_interval = 0.25,
}
