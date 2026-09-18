--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- Net.lua - the ONE general dispatcher for client<->GS "window use" packets. The
-- DLL parses every incoming packet and hands this module a single callback:
-- (windowId, iParam, result, reader). Here we route it to the handler a feature
-- script registered for (windowId, iParam). Adding or changing handlers is pure
-- Lua - it never needs a DLL rebuild.
--
--   Routing key:  windowId (which UI/module owns it)  ->  iParam (which action)
--
-- Register a handler (from any script). Bind to a LOWERCASE local - `Net` and
-- `UI` are global tables the client provides and a same-name local would shadow them:
--   local net = require("Net")
--   net.on(R.win.demo, 5, function(result, reader, iParam, windowId)
--       if result == 0 then local n = reader:dword() ... end
--   end)
--   -- iParam omitted => the window's default/fallback handler:
--   net.on(R.win.demo, function(result, reader, iParam) ... end)
--
-- Send a use packet (e.g. from a button):
--   net.send(R.win.demo, 5):dword(123):text("hello"):send()
--   -- (:send() sizes the packet automatically from the appended payload)
-- ============================================================================

local M = {}

-- handlers[windowId][iParam] = fn ; handlers[windowId].default = fn
local handlers = {}

-- Register a handler. Pass iParam to bind a specific action, or omit it (pass the
-- function as the 2nd arg) to register the window's default/fallback handler.
function M.on(windowId, iParam, fn)
	if type(iParam) == "function" then
		fn, iParam = iParam, nil
	end

	handlers[windowId] = handlers[windowId] or {}
	handlers[windowId][iParam ~= nil and iParam or "default"] = fn
	return M
end

-- Remove a handler put in place by on(). Omit iParam to drop the fallback.
function M.off(windowId, iParam)
	local w = handlers[windowId]
	if not w then return end
	w[iParam ~= nil and iParam or "default"] = nil
end

-- Build a use packet bound to (windowId, iParam). Append payload with the writer
-- (:byte/:word/:dword/:qword/:float/:double/:str/:text), then :send().
function M.send(windowId, iParam)
	return Net.WindowUse(windowId, iParam or 0)
end

-- The single dispatcher the client calls for every incoming window-use packet.
Net.OnWindowUse(function(windowId, iParam, result, reader)
	local w = handlers[windowId]
	if not w then return end

	local fn = w[iParam] or w.default
	if fn then
		fn(result, reader, iParam, windowId)
	end
end)

return M
