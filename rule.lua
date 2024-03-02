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

		for _, option in pairs(self.options) do
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