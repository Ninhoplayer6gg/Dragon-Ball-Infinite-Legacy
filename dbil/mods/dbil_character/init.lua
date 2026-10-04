-- Character foundation: everything that describes a fighter and its state.

-- Core attributes shared by every race. Order is used by the UI.
dbil.ATTRIBUTES = { "strength", "resistance", "speed", "ki_control", "ki_capacity" }
dbil.ATTRIBUTE_INFO = {
	strength = { name = "Força", short = "FOR" },
	resistance = { name = "Resistência", short = "RES" },
	speed = { name = "Velocidade", short = "VEL" },
	ki_control = { name = "Controle de Ki", short = "CTL" },
	ki_capacity = { name = "Capacidade de Ki", short = "CAP" },
}

dbil.include("src/races.lua")
dbil.include("src/model.lua")
dbil.include("src/accounts.lua")
dbil.include("src/sessions.lua")
dbil.include("src/physics.lua")
dbil.include("src/stats.lua")
dbil.include("src/resources.lua")
dbil.include("src/power.lua")
dbil.include("src/actors.lua")
dbil.include("src/appearance.lua")
dbil.include("src/animation.lua")
