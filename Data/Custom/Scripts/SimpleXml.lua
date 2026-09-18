--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- SimpleXml.lua - plain XML reader for client scripts.
--
--   local xml = require("SimpleXml")
--   local root = xml.LoadFile("Data\\Custom\\Config\\MyShop.xml")
--   local list = xml.Find(root, "ItemList")
--
--   for _, item in ipairs(list.kids) do
--       if item.name == "Item" then
--           local id = tonumber(item.attr.Id)
--       end
--   end
--
-- Returns a plain node table, the same shape the server's Includes\SimpleXml.lua
-- produces, so configuration is traversed identically on both sides:
--
--   { name = "Item", attr = { Id = "5", Name = "Sword" }, kids = { node, ... } }
--
-- Attribute values are always strings - convert with tonumber().
--
-- Deliberately small: it handles the flat, well-formed config files shipped
-- with the client. It does NOT handle CDATA, entities or a '>' inside an
-- attribute value.
-- ============================================================================

local M = {}

local function decodeEntities(s)
	return (s:gsub("&(#?%w+);", function(name)
		if name == "amp" then return "&" end
		if name == "lt" then return "<" end
		if name == "gt" then return ">" end
		if name == "quot" then return "\"" end
		if name == "apos" then return "'" end

		local hex = name:match("^#[xX](%x+)$")
		local dec = name:match("^#(%d+)$")
		local n = (hex and tonumber(hex, 16)) or (dec and tonumber(dec))

		if n and n <= 255 then
			return string.char(n)
		end
	end))
end

local function parseAttributes(text)
	local attr = {}

	for key, quote, value in text:gmatch("([%w_:%-]+)%s*=%s*([\"'])(.-)%2") do
		attr[key] = decodeEntities(value)
	end

	return attr
end

function M.Parse(text)
	if type(text) ~= "string" then
		return nil, "SimpleXml: expected a string"
	end

	-- the shipped configs document their format in comments, and those comments
	-- contain sample markup
	text = text:gsub("<!%-%-.-%-%->", "")

	local stack = {}
	local root = nil
	local pos = 1

	while true do
		local open = text:find("<", pos, true)

		if open == nil then
			break
		end

		local close = text:find(">", open, true)

		if close == nil then
			break
		end

		local lead = text:sub(open + 1, open + 1)

		if lead == "?" or lead == "!" then
			-- <?xml ... ?> and <!DOCTYPE ...>
		elseif lead == "/" then
			table.remove(stack)
		else
			local body = text:sub(open + 1, close - 1)
			local selfClosing = body:sub(-1) == "/"

			if selfClosing then
				body = body:sub(1, -2)
			end

			local name, rest = body:match("^([%w_:%-]+)%s*(.*)$")

			if name ~= nil then
				local node = { name = name, attr = parseAttributes(rest), kids = {} }
				local parent = stack[#stack]

				if parent ~= nil then
					parent.kids[#parent.kids + 1] = node
				elseif root == nil then
					root = node
				end

				if selfClosing == false then
					stack[#stack + 1] = node
				end
			end
		end

		pos = close + 1
	end

	if root == nil then
		return nil, "SimpleXml: no root element"
	end

	return root
end

function M.LoadFile(path)
	local file = io.open(path, "rb")

	if file == nil then
		return nil, ("SimpleXml: cannot open '%s'"):format(path)
	end

	local text = file:read("*a")
	file:close()

	return M.Parse(text)
end

-- First direct child with this name, nil when absent
function M.Find(node, name)
	if node == nil then
		return nil
	end

	for _, child in ipairs(node.kids) do
		if child.name == name then
			return child
		end
	end

	return nil
end

return M
