local base_path = ...
local function rrequire(path)
	return require(base_path .. '.' .. path)
end

local elgram = {}
elgram.rule = rrequire 'rule'

return elgram