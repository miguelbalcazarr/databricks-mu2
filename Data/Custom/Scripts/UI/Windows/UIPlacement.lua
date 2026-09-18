--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- UIPlacement.lua - a ruler for building windows.
--
-- Laying a window out means guessing coordinates, reloading, and guessing again.
-- This panel removes the guessing: point the mouse at something and it tells you
-- where that something is, in the very numbers you would type into a script.
--
-- F11 toggles it.
--
-- ---- what it reports --------------------------------------------------------
--   cursor   where the mouse is. Paste it straight into x/y.
--   over     which Lua window is under the cursor, and its id
--   pos      that window's top-left corner
--   size     its declared size, and in brackets what it covers on screen
--   anchor   what THIS panel's own anchor resolved to
--   canvas   the coordinate space all of the above is expressed in
--
-- ---- how to use it ----------------------------------------------------------
-- Placing a control at a fixed spot:
--   1. open the window you are working on, and this panel
--   2. put the cursor where the control's TOP-LEFT corner should sit
--   3. read `cursor` and use those two numbers as x/y
--
-- Sizing a panel: point at one corner, note `cursor`, point at the other, and
-- subtract. The difference is w/h.
--
-- Checking an anchor: `anchor` shows what the anchor you gave THIS panel worked
-- out to. Change ANCHOR/MARGIN below, press F9, and read the new numbers - which
-- is the quickest way to see where "bottomright with margin {6,140}" actually
-- lands before committing it to your own window.
--
-- `size 280x380 (140x190)` = declared size, then what it covers on screen (x/y
-- are not scaled, sizes are). Any window in Registry.lua shows up here by name.
--
-- Delete this file to drop the helper - nothing depends on it.
-- ============================================================================

local ui = require("UI")
local R  = require("Registry")
local Enums = require("Enums")

-- ---- placement (the only thing you normally touch) --------------------------
-- Anchors: topleft top topright left center right bottomleft bottom bottomright
-- margin = { x, y } measured inward from the anchored edge.
--   topleft     - taken by the character status and the party list
--   topright    - taken by the minimap
--   bottom      - taken by the skill bar
-- The right edge, vertically centred, is clear in a default layout.
local ANCHOR = "right"
local MARGIN = { 6, 0 }

-- Rows are 20px (a 16px box clips a larger font); H covers 7 rows + gaps + margin.
local W, H = 214, 176

local win = ui.Window{
	id = R.win.uiplacement,
	mode = "hud",
	clickThrough = true,
	anchor = ANCHOR,
	margin = MARGIN,
	w = W, height = H,
}

if win then
	win:background(function(s, h)
		h:renderColor(0, 0, s.w, s.h, RGBA(0, 0, 0, 110))
		h:renderColor(0, 0, s.w, 1, RGBA(198, 157, 0, 140))
		h:renderColor(0, s.h - 1, s.w, 1, RGBA(198, 157, 0, 140))
	end)

	-- slide=false keeps these readouts from sliding sideways on hover.
	local WHITE = RGBA(220, 220, 220, 255)
	local BLUE  = RGBA(150, 200, 255, 255)

	local col = win:Column{ top = 6, padding = 8, spacing = 4, align = "center" }
	col:Label("UI Placement", { h = 20, color = RGBA(198, 157, 0, 255), slide = false, bold = true })

	-- seeded with real text (an empty label renders nothing until the first tick)
	local lCursor = col:Label("cursor -", { color = WHITE, slide = false, h = 20, scale = 1.05 })
	local lOver   = col:Label("over -",   { color = BLUE,  slide = false, h = 20, scale = 1.05 })
	local lPos    = col:Label("pos -",    { color = BLUE,  slide = false, h = 20, scale = 1.05 })
	local lSize   = col:Label("size -",   { color = BLUE,  slide = false, h = 20, scale = 1.05 })
	local lSelf   = col:Label("anchor -", { color = WHITE, slide = false, h = 20, scale = 1.05 })

	col:Label(("canvas  %.0fx%.0f   scale %.2f"):format(UI.ScreenWidth(), UI.ScreenHeight(), UI.Scale()),
		{ color = RGBA(150, 150, 150, 255), slide = false, h = 20, scale = 1.05 })

	-- Every window registered in Registry.lua - added windows show up by name.
	local names = ui.idNames(R.win)

	local function windowUnderCursor()
		for name, id in pairs(names) do
			if id ~= R.win.uiplacement then
				local w = UI.GetWindow(id)

				-- CheckMousePos scales w/h by UI.Scale() to match what is drawn
				if w and w.visible and Input.CheckMousePos(w.x, w.y, w.width, w.height) then
					return name, w
				end
			end
		end
	end

	-- refresh every 3rd frame - live enough, and off the per-frame path
	local frame = 0

	Event.on("update", function()
		if Input.KeyPressed(VK.F11) then
			win:show(not win:isVisible())
		end

		frame = frame + 1

		if frame % 3 ~= 0 then
			return
		end

		lCursor.text = ("cursor  %.0f, %.0f"):format(Input.MouseX(), Input.MouseY())

		local name, w = windowUnderCursor()

		if name then
			local scale = UI.Scale()
			lOver.text = ("over  %s #%d"):format(name, w.id)
			lPos.text  = ("pos  %.0f, %.0f"):format(w.x, w.y)
			-- declared size first, then what it actually covers on screen
			lSize.text = ("size  %.0fx%.0f  (%.0fx%.0f)"):format(w.width, w.height,
				w.width * scale, w.height * scale)
		else
			lOver.text = "over  -"
			lPos.text  = "pos  -"
			lSize.text = "size  -"
		end

		local h = win:handle()
		lSelf.text = ("anchor  %s -> %.0f, %.0f"):format(ANCHOR, h.x, h.y)
	end)

	Event.on("ingame", function()
		win:show(true)
	end)

	if Input.GameState() == Enums.GameState.IN_GAME then
		win:show(true)
	end
end

