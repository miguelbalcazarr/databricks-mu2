--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================
-- Client-side Lua UI demo - a scroll PANEL (framed "table") inside a window.
-- Deploy to:  .\Data\Custom\Scripts\UI\Windows\Demo.lua
--   (libraries: .\Data\Custom\Scripts\UI\{UI,Registry,Net}.lua)
--
-- The window itself is a fixed size. Static controls (name/Send) live directly
-- in the window; below them sits a framed scroll panel with its OWN scrollbar and
-- its OWN style (here: coloured). Multiple panels in one window can each look
-- different, and panels can be nested (win:Panel -> panel:Panel).
--
-- Skinning with a texture instead of colours (per panel):
--   list:setScrollbarSkin{ up={slot,sx,sy,sw,sh}, down={..}, upPressed={..},
--                          downPressed={..}, thumb={..}, track={..} }
-- (Load the atlas first with UI.LoadImage(slot, "Custom\\...\\scrollbar.tga").)
-- ============================================================

local ui = require("UI")
local R  = require("Registry")          -- central source of truth for ids/slots
local net = require("Net")              -- installs the window-use dispatcher
local Enums = require("Enums")          -- named client values (Enums.Group.VALUE)

local OP_SEND, OP_ECHO = 100, 101       -- packet opcodes: explicit constants (never pooled)
local ACT_PING = 1                      -- window-use action id (routing: R.win.demo -> ACT_PING)

local win = ui.Window{
	id = R.win.demo,
	mode = "window",                -- floating: server-gated open, ESC closes it
	center = true,
	w = 280, height = 380,          -- FIXED window; the list scrolls, not the window
	header = 34,
	title = "Lua Demo",
	titleColor = RGBA(255, 255, 255, 255),
	drag = { 0, 0, 280, 34 },
	skin = {
		slot = R.slot.frame,        -- central named slot; reuse it anywhere to share this atlas
		path = "Custom\\Interface\\UI\\CommandWindowFrame.tga",
		top    = { 327, 0,   323, 22 },
		middle = { 327, 80,  323, 6  },
		bottom = { 327, 158, 323, 22 },
	},
}

if win then
	-- Static header controls (live directly in the window, above the list).
	local top = win:Column{ top = 42, padding = 16, spacing = 6, align = "center" }
	top:Label("Enter your name:", { color = RGBA(220, 220, 220, 255) })

	-- maxBytes/minBytes count bytes (matching a DB column): 10 bytes is 10 Latin or
	-- ~3 CJK chars. maxLen is per keystroke, minLen only at submit.
	local input = top:TextInput{
		w = 200, h = 20, minBytes = 4, maxBytes = 10,
		placeholder = "Enter a name", placeholderAlign = 4,
		backColor = RGBA(0, 0, 0, 160), color = RGBA(255, 255, 255, 255),
	}

	-- Status label + a capacity bar under the field. The bar fills by bytes used.
	local BAR_MAX = 10
	local barY = input.y + input.height + 2

	local barTrack = win:Panel{ x = input.x, y = barY, w = input.width, h = 3,
		back = RGBA(0, 0, 0, 150) }
	local barFill = win:Panel{ x = input.x, y = barY, w = 1, h = 3,
		back = RGBA(198, 157, 0, 230) }

	barFill:show(false)

	local status = top:Label("", { color = RGBA(255, 120, 120, 255), scale = 0.85, slide = false })

	local sendBtn = top:Button("Send", {
		w = 120, h = 28,
		onClick = function()
			local txt = input.text

			if not ui.textOk(input) then
				status.text = "Name is too short"
			else
				status.text = ""
				-- textCodePage, not .text: this one is bound for a name column, so it
				-- goes in the encoding the game and the database use
				Net.CreatePacket(OP_SEND):text(input.textCodePage):send()
			end
		end,
	})

	-- End-to-end "window use" demo. Sends (windowId=R.win.demo, iParam=
	-- ACT_PING) with a free payload; the GS handler echoes data back + a result,
	-- which the net.on() handler below reads and shows in `useEcho`.
	local useCount = 0
	-- slide=false keeps a readout from sliding sideways on hover.
	local useEcho = top:Label("use: (no reply yet)", { color = RGBA(255, 220, 120, 255), scale = 0.85, slide = false })

	local useBtn = top:Button("Use", {
		w = 120, h = 28,
		onClick = function()
			useCount = useCount + 1
			net.send(R.win.demo, ACT_PING)
				:dword(useCount)          -- arbitrary payload: a counter ...
				:text(input.text)         -- ... and the input text
				:send()
		end,
	})

	-- Handler for (R.win.demo, ACT_PING). Fires when the GS answers.
	-- Reads back only what the server actually appended (payload is optional).
	net.on(R.win.demo, ACT_PING, function(result, reader)
		if reader:remaining() >= 4 then
			local n = reader:dword()
			local msg = reader:text()
			useEcho.text = ("use reply: result=%d n=%d %q"):format(result, n, msg)
		else
			useEcho.text = "use reply: result=" .. result .. " (no data)"
		end
	end)

	-- A framed, independently-scrollable panel (the "table") inside the window. No
	-- id needed. A panel takes an explicit y - place it below where the column ends.
	local list = win:Panel{
		x = 14, y = 202, w = 252, h = 152,
		back = RGBA(0, 0, 0, 90),                 -- panel fill / frame
		scrollbar = true, scrollbarWidth = 12, scrollbarMargin = 6,
		scrollbarAutoHide = false,                -- true = fade in on hover
		colors = {                                -- per-panel scrollbar style
			track        = RGBA(0, 0, 0, 120),
			arrow        = RGBA(60, 40, 25, 255),
			arrowPressed = RGBA(150, 90, 45, 255),
			thumb        = RGBA(120, 90, 60, 220),
			thumbDrag    = RGBA(210, 140, 70, 255),
			glyph        = RGBA(230, 170, 100, 255),
			glyphPressed = RGBA(255, 215, 150, 255),
		},
	}

	-- Instead of `colors`, you can skin the bar straight from the WINDOW atlas
	-- (R.slot.frame) - no extra bitmap. Just give the cut coords; slot is shared:
	--   list:setScrollbarSkin{
	--       slot = R.slot.frame,               -- reuse the already-loaded window bitmap
	--       up   = { sx, sy, sw, sh }, down        = { sx, sy, sw, sh },
	--       upPressed = { sx, sy, sw, sh }, downPressed = { sx, sy, sw, sh },
	--       thumb = { sx, sy, sw, sh },        -- (+ thumbTop/thumbBot for a 3-slice thumb)
	--       track = { sx, sy, sw, sh },
	--   }
	-- (a piece can override with its own slot as {slot,sx,sy,sw,sh} to mix atlases.)

	local col = list:Column{ top = 8, padding = 10, spacing = 6, align = "center" }
	col:Label("-- items --", { color = RGBA(180, 200, 255, 255), scale = 0.9 })

	local itemBtns = {}

	for i = 1, 12 do
		itemBtns[i] = col:Button("Item " .. i, { w = 150, h = 26 })
	end

	local echo = col:Label("", { color = RGBA(120, 255, 120, 255), scale = 0.85, slide = false })
	list:fit()   -- publish content height -> scrolls on overflow

	-- Skin every button from the window's own atlas so they read as one set.
	-- A state left unset falls back to NORMAL.
	local function skinButton(btn)
		btn:setImage(ui.STATE.NORMAL,  R.slot.frame, 653, 76,  123, 33)
		btn:setImage(ui.STATE.HOVER,   R.slot.frame, 780, 76,  123, 33)
		btn:setImage(ui.STATE.PRESSED, R.slot.frame, 780, 113, 123, 33)
	end

	-- Wait for the atlas to finish loading before skinning.
	local skinned = false

	Event.on("update", function()
		if win:textureReady() and not skinned then
			skinButton(sendBtn)
			skinButton(useBtn)

			for _, btn in ipairs(itemBtns) do
				skinButton(btn)
			end

			skinned = true
		end
	end)

	Net.OnPacket(OP_ECHO, function(reader)
		echo.text = "Echo: " .. reader:text()
	end)

	-- Full / too-short feedback (no number - it would mislead across codepages).
	Event.on("update", function()
		if Input.KeyPressed(VK.F10) then win:show(not win:isVisible()) end

		local used = input.bytesUsed

		if used > 0 then
			local ratio = used / BAR_MAX

			if ratio > 1 then
				ratio = 1
			end

			barFill:handle().width = input.width * ratio
			barFill:show(true)
		else
			barFill:show(false)
		end

		if used >= BAR_MAX then
			status.text = "Maximum length reached"
		elseif status.text == "Maximum length reached" then
			status.text = ""
		elseif status.text ~= "" and ui.textOk(input) then
			-- clear the complaint once the value is valid
			status.text = ""
		end
	end)

	Event.on("ingame", function()
		win:show(true)
		win:bringToFront()
	end)

	if Input.GameState() == Enums.GameState.IN_GAME then
		win:show(true)
		win:bringToFront()
	end
end

