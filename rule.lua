local Rule = {}
Rule.__index = Rule

function Rule.new(name)
	if not name then error('rule must have a name') end
	return setmetatable({name = name, options = {}, calc_follow_set = {}}, Rule)
end

local epsilon = {}
function Rule:first()
	if self.first_set then return self.first_set end

	local first_set = {}

	local changed = true
	while changed do
		changed = false

		for _, option in ipairs(self.options) do
			if #option == 0 then
				if not first_set[epsilon] then
					first_set[epsilon] = true
					changed = true
				end
			else
				local i = 1
				while option[i] == self do
					i = i + 1
				end
				local f
				repeat
					f = nil
					if option[i] then
						if getmetatable(option[i]) == Rule and option[i] ~= self then
							f = option[i]:first()
						else
							f = {[option[i]] = true}
						end
					end

					if f then
						for key, _ in pairs(f) do
							if not first_set[key] then
								first_set[key] = true
								changed = true
							end
						end
					end

					i = i + 1
				until not f or not f[epsilon]
			end
		end
	end

	self.first_set = first_set
	return self.first_set
end

function Rule:follow()
	if self.follow_set then return self.follow_set end

	local changed = true
	while changed do
		changed = false

		for _, option in ipairs(self.options) do
			local nullable = true
			local quitloop = false
			local i = #option
			while not quitloop and i >= 1 do
				if getmetatable(option[i]) == Rule then
					if nullable then
						for token, _ in pairs(self.calc_follow_set) do
							if not option[i].calc_follow_set[token] then
								changed = true
							end

							option[i].calc_follow_set[token] = true
						end
					else
						local first = getmetatable(option[i + 1]) == Rule and option[i + 1]:first() or {[option[i + 1]] = true}
						for token, _ in pairs(first) do
							if not option[i].calc_follow_set[token] then
								changed = true
							end

							option[i].calc_follow_set[token] = true
							quitloop = true
						end
					end

					-- recalculate follow set
					if not option[i].recalculating then
						option[i].follow_set = nil
						option[i].recalculating = true
						option[i]:follow()
						option[i].recalculating = false
					end
				end

				if getmetatable(option[i]) ~= Rule or not option[i]:first()[epsilon] then
					nullable = false
				end

				i = i - 1
			end
		end
	end

	self.follow_set = self.calc_follow_set
	return self.follow_set
end

function Rule:parse(tokens, is_self)
	-- make a shallow copy of the tokens
	-- should only consist of strings anyway
	tokens = { unpack(tokens) }

	local found = false
	for first_token, _ in pairs(self:first()) do
		if tokens[1] == first_token then
			found = true
		end
	end

	if not found then
		return nil
	end

	for _, option in ipairs(self.options) do
		local match = true
		local consumed_count = 0
		local result = { type = self }
		local tokens_copy = { unpack(tokens) }
		for _, required_token in ipairs(option) do
			if match then
				if getmetatable(required_token) == Rule then
					if is_self and required_token == self then
						match = false
					else
						local inner_result, inner_consumed_count = required_token:parse({ unpack(tokens_copy) }, required_token == self)
	
						if inner_result then
							table.insert(result, inner_result)
							consumed_count = consumed_count + inner_consumed_count
							for _ = 1, inner_consumed_count do
								table.remove(tokens_copy, 1)
							end
						else
							match = false
						end
					end
				elseif tokens_copy[1] == required_token then
					table.insert(result, table.remove(tokens_copy, 1))
					consumed_count = consumed_count + 1
				else
					match = false
				end
			end
		end

		if match then
			return result, consumed_count
		end
	end

	return nil
end

local random = love and love.math.random or math.random
function Rule:generate()
	local result = {}
	local option = self.options[random(1, #self.options)]

	for _, token in ipairs(option) do
		if getmetatable(token) == Rule then
			local inner_result = token:generate()
			for _, inner_token in ipairs(inner_result) do
				table.insert(result, inner_token)
			end
		else
			table.insert(result, token)
		end
	end

	return result
end

function Rule:option(...)
	table.insert(self.options, {...})
	self.first_set = nil
	self.follow_set = nil
	self.calc_follow_set = {}
	return self
end

function Rule:__tostring()
	local s = '<' .. self.name .. '> ::='
	
	for i, option in ipairs(self.options) do
		for _, elem in ipairs(option) do
			if getmetatable(elem) == Rule then
				s = s .. ' <' .. elem.name .. '>'
			else
				s = s .. ' ' .. elem
			end
		end

		if self.options[i + 1] then
			s = s .. ' |'
		end
	end

	return s
end

return Rule