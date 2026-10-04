-- Generic named registries used by races, techniques, transformations,
-- enemies, quests... Each registry validates definitions with a schema and
-- keeps registration order for stable UI listings.

local registry = {}
dbil.registry = registry

local Registry = {}
Registry.__index = Registry

--- Creates a registry.
-- opts.schema: dbil.schema node used to validate definitions
-- opts.on_register(def): optional hook after validation
function registry.new(kind, opts)
	opts = opts or {}
	return setmetatable({
		kind = kind,
		schema = opts.schema,
		on_register = opts.on_register,
		defs = {},
		order = {},
	}, Registry)
end

function Registry:register(id, def)
	assert(type(id) == "string" and id:match("^[%w_:]+$"),
		self.kind .. ": invalid id '" .. tostring(id) .. "'")
	assert(not self.defs[id], self.kind .. " already registered: " .. id)
	if self.schema then
		def = dbil.schema.check(def, self.schema, self.kind .. " '" .. id .. "'")
	end
	def.id = id
	if self.on_register then
		self.on_register(def)
	end
	self.defs[id] = def
	self.order[#self.order + 1] = id
	return def
end

function Registry:get(id)
	return self.defs[id]
end

function Registry:exists(id)
	return self.defs[id] ~= nil
end

--- Iterates definitions in registration order.
function Registry:iter()
	local i = 0
	return function()
		i = i + 1
		local id = self.order[i]
		if id then
			return id, self.defs[id]
		end
	end
end

function Registry:ids()
	return { unpack(self.order) }
end
