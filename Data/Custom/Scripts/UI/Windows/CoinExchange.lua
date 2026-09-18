--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- CoinExchange.lua - converts WCoin into Ruud at a rate the server owns.
--
-- The window shows the current rate and balances, takes an amount, and lists
-- the character's past conversions in a scrolling panel underneath.
--
-- Its HUD counterpart is CoinExchangeHud.lua, which shows the rate and today's
-- allowance without the window being open.
--
-- A worked feature that shows the whole system at once - window, HUD panel, both
-- protocol channels, a scrolling list. The daily allowance and the history are
-- stored per character in the database; the server half sets that up (see its
-- SQL Scripts\CoinExchange.sql).
--
-- F12 toggles it, and the X in the header closes it.
-- ============================================================================

local ui  = require("UI")
local R   = require("Registry")
local net = require("Net")
local P   = require("Protocol")

local S = P.Exchange

-- This side's half of the system state. Global so the HUD script can read it;
-- the server keeps its own table under the same name.
Exchange = Exchange or { rate = 0, usedToday = 0, dailyLimit = 0, history = {} }

local ROW_H, ROW_GAP = 16, 4

-- Hotkeys are global to the client and the shipped demos already hold several:
-- F9 reloads Lua in dev mode, F10 is Demo.lua, F11 is UIPlacement.lua.
local OPEN_KEY = VK.F12

-- Grid. Header plaque at its natural 73px; title and close button sit in its bar.
local W, H       = 280, 346
local HEADER_H   = 73
local TITLE_Y    = 44    -- inside the plaque's bar, not above it
local BOTTOM_H   = 28
local LIST_Y     = 230
local LIST_H     = 82

-- One atlas covers the lot: frame, wide button and close X are all in
-- CommandWindowFrame.tga, the same bitmap the game's own command window uses.
local SKIN = {
	-- Shared slot (see Registry.lua) - the Demo window loads the same atlas too.
	slot   = R.slot.frame,
	path   = "Custom\\Interface\\UI\\CommandWindowFrame.tga",
	top    = { 653,  0, 325, 73 },   -- header plaque
	middle = { 327, 60, 323,  8 },   -- a slice of the body, repeated down
	bottom = {   1, 348, 323, 36 },  -- the closing edge of the bottom piece
	topH   = HEADER_H,
	botH   = BOTTOM_H,
}

-- Close-button cuts from the native command window.
local BTN_NORMAL  = { 653, 76,  123, 33 }
local BTN_HOVER   = { 780, 76,  123, 33 }
local BTN_PRESSED = { 780, 113, 123, 33 }

local X_NORMAL  = { 1000,  0, 20, 20 }
local X_HOVER   = { 1000, 20, 20, 20 }
local X_PRESSED = {  980, 20, 20, 20 }

-- The plaque is authored 325 wide and stretched to W, so positions on it scale by
-- W/325. The native close button sits at x=270 in that 325.
local PLAQUE_W  = 325
local PLAQUE_K  = W / PLAQUE_W
local X_SIZE    = 20 * PLAQUE_K
local X_X       = 270 * PLAQUE_K
local X_Y       = 45              -- vertical is not stretched: topH is the natural 73

local win = ui.Window{
	id = R.win.exchange,
	center = true,
	w = W, height = H,
	title = "Coin Exchange",
	titleY = TITLE_Y,
	titleColor = RGBA(226, 206, 160, 255),
	-- no `header` (the plaque already has an edge); drag stops short of the close button
	drag = { 0, 0, X_X - 4, HEADER_H },
}

if win then
	local col = win:Column{ top = HEADER_H + 9, padding = 16, spacing = 6, align = "center" }

	-- Thousands separator so long balances stay readable.
	local function grouped(n)
		local s = tostring(math.floor(n or 0))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	local lRate  = col:Label("-", { slide = false, color = RGBA(212, 172, 24, 255) })
	local lWCoin = col:Label("WCoin  -", { slide = false, scale = 0.9 })
	local lRuud  = col:Label("Ruud  -",  { slide = false, scale = 0.9 })

	local input = col:TextInput{
		w = 180, h = 20,
		numeric = true, maxValue = S.MAX,
		placeholder = "WCoin to convert",
	}

	local status = col:Label("", { color = RGBA(255, 120, 120, 255), slide = false })

	local convertBtn = col:Button("Convert", {
		w = 120, h = 26,
		onClick = function()
			local amount = tonumber(input.text) or 0
			status.text = ""
			net.send(S.id, S.CONVERT):dword(amount):send()
		end,
	})

	win:frameSkin(SKIN)

	-- Close button - on the raw handle (header corner, not in the column).
	local closeBtn = win:handle():addButton(win:nextId(), X_X, X_Y, X_SIZE, X_SIZE)
	closeBtn.click = function() win:show(false) end

	-- The list of past conversions. Rows are created once and refilled.
	local list = win:Panel{
		x = 14, y = LIST_Y, w = W - 28, h = LIST_H,
		back = RGBA(0, 0, 0, 90),
		scrollbar = true,
	}

	local rows = {}
	local histCol = list:Column{ top = 8, padding = 10, spacing = ROW_GAP, align = "left" }

	local function setHistory(entries)
		for _, row in ipairs(rows) do
			row.visible = false
		end

		for i, entry in ipairs(entries) do
			local row = rows[i]

			if row == nil then
				row = histCol:Label("", { scale = 0.9, slide = false })
				rows[i] = row
			end

			row.text = ("%s  %d -> %d"):format(entry.date, entry.spent, entry.gained)
			row.visible = true
		end

		-- the laid-out height only ever grows, so publish what is actually shown
		list:handle():setContentHeight(#entries * (ROW_H + ROW_GAP) + 16)
	end

	net.on(S.id, S.RATE, function(result, reader)
		Exchange.rate = reader:dword()

		local wcoin, ruud = reader:dword(), reader:dword()
		lRate.text  = ("%d WCoin = 1 Ruud"):format(Exchange.rate)
		lWCoin.text = "WCoin  " .. grouped(wcoin)
		lRuud.text  = "Ruud  " .. grouped(ruud)
	end)

	net.on(S.id, S.CONVERT, function(result)
		if result == S.RESULT.OK then
			input.text = ""
			status.text = ""
		elseif result == S.RESULT.NO_FUNDS then
			status.text = "Not enough WCoin."
		elseif result == S.RESULT.LIMIT then
			status.text = "Daily limit reached."
		else
			status.text = ("Enter a multiple of %d, %d at least."):format(Exchange.rate, S.MIN)
		end
	end)

	net.on(S.id, S.HISTORY, function(result, reader)
		local entries = {}

		for i = 1, reader:byte() do
			entries[i] = {
				date   = reader:text(),
				spent  = reader:dword(),
				gained = reader:dword(),
			}
		end

		Exchange.history = entries
		setHistory(entries)
	end)

	-- Skin the buttons from the window's atlas once it has finished loading.
	local skinned = false

	Event.on("update", function()
		if Input.KeyPressed(OPEN_KEY) then
			win:show(not win:isVisible())
		end

		if not skinned and win:textureReady() then
			convertBtn:setImage(ui.STATE.NORMAL,  R.slot.frame, unpack(BTN_NORMAL))
			convertBtn:setImage(ui.STATE.HOVER,   R.slot.frame, unpack(BTN_HOVER))
			convertBtn:setImage(ui.STATE.PRESSED, R.slot.frame, unpack(BTN_PRESSED))

			closeBtn:setImage(ui.STATE.NORMAL,  R.slot.frame, unpack(X_NORMAL))
			closeBtn:setImage(ui.STATE.HOVER,   R.slot.frame, unpack(X_HOVER))
			closeBtn:setImage(ui.STATE.PRESSED, R.slot.frame, unpack(X_PRESSED))

			skinned = true
		end
	end)
end

