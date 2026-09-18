--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- CoinExchangeHud.lua - the Coin Exchange ticker.
--
-- A HUD panel: it shows without asking the server, ESC does not close it and the
-- world stays clickable underneath. It reads the rate from the general channel,
-- so it works whether or not the exchange window has ever been opened.
--
-- Drawn from shapes, no assets. Delete this file to drop the ticker; the window
-- itself does not depend on it.
-- ============================================================================

local ui = require("UI")
local R  = require("Registry")
local Enums = require("Enums")
local P  = require("Protocol")

local S = P.Exchange

-- CoinExchange.lua creates this table too. Whichever script loads first wins,
-- and both start it the same way.
Exchange = Exchange or { rate = 0, usedToday = 0, dailyLimit = 0, history = {} }

-- Palette (gold = the game's own header colour, RGB(198,157,0)).
local GOLD      = RGBA(212, 172, 24, 255)
local GOLD_DIM  = RGBA(126, 100,  8, 235)   -- outer border
local EDGE_HI   = RGBA(160, 130, 40, 120)   -- 1px highlight along the very top
local HEADER_BG = RGBA( 54,  41,  14, 250)
local BODY_BG   = RGBA( 14,  11,   7, 236)
local TEXT      = RGBA(238, 234, 222, 255)
local TEXT_DIM  = RGBA(146, 138, 120, 255)
local RAIL_BG   = RGBA( 48,  40,  26, 255)  -- must read against the body, not vanish
local RAIL_EDGE = RGBA(  0,   0,   0, 180)
local RAIL_FILL = RGBA(212, 172,  24, 255)

-- ---- placement --------------------------------------------------------------
-- "bottomright" so margin.y is honoured (a centred anchor ignores it); 124 lands
-- this panel just below UIPlacement.
local ANCHOR = "bottomright"
local MARGIN = { 6, 124 }

-- Layout grid - all row positions and heights in one place. Text rows get 18
-- units: a shorter box loses its ascenders at half UI scale.
local W, H       = 214, 104
local PAD        = 9
local HEADER_H   = 22
local ROW_TEXT_H = 18
local ROW_RATE   = 26    -- "10 WCoin = 1 Ruud" - the hero line
local ROW_LABEL  = 50    -- "today" + "100 / 100k"
local RAIL_Y     = 72
local RAIL_H     = 4
local ROW_HINT   = 80    -- ends at 96, leaving 3 under it and 9 at the sides

-- The key that opens the exchange window (printed in the hint below).
local OPEN_KEY   = "F12"

local hud = ui.Window{
	id = R.win.exchangehud,
	anchor = ANCHOR, margin = MARGIN,
	mode = "hud", clickThrough = true,
	w = W, height = H,
}

if hud then
	-- Compact figures - a narrow HUD strip has no room for long numbers.
	local function compact(n)
		n = math.floor(n or 0)

		if n >= 1000000 then
			return ("%.1fM"):format(n / 1000000)
		elseif n >= 1000 then
			return ("%dk"):format(n / 1000)
		end

		return tostring(n)
	end

	hud:background(function(s, h)
		local innerW = s.w - PAD * 2

		-- body, header, and the hairline that separates them
		h:renderColor(0, 0, s.w, s.h, BODY_BG)
		h:renderColor(0, 0, s.w, HEADER_H, HEADER_BG)
		h:renderColor(0, HEADER_H, s.w, 1, GOLD_DIM)

		-- border + top highlight so it reads as a raised panel, not a smudge
		h:renderColor(0, 0, s.w, 1, GOLD_DIM)
		h:renderColor(0, 1, s.w, 1, EDGE_HI)
		h:renderColor(0, s.h - 1, s.w, 1, GOLD_DIM)
		h:renderColor(0, 0, 1, s.h, GOLD_DIM)
		h:renderColor(s.w - 1, 0, 1, s.h, GOLD_DIM)

		-- header caption, centred in the header strip
		h:renderText("COIN EXCHANGE", 0, 0, s.w, HEADER_H, ALIGN_CENTER, GOLD, FontM)

		-- the rate is what the panel is for, so it gets the largest type and gold
		if Exchange.rate > 0 then
			h:renderText(("%d WCoin = 1 Ruud"):format(Exchange.rate),
				0, ROW_RATE, s.w, ROW_TEXT_H, ALIGN_CENTER, TEXT, FontM)
		else
			h:renderText("connecting...", 0, ROW_RATE, s.w, ROW_TEXT_H, ALIGN_CENTER, TEXT_DIM, FontM)
		end

		-- Today's allowance. Skip the row until the first ticker packet sets a limit.
		if Exchange.dailyLimit > 0 then
			local used = math.min(Exchange.usedToday / Exchange.dailyLimit, 1)

			-- Caption left, figure right - just the amount used; the rail shows the ratio.
			h:renderText("today", PAD, ROW_LABEL, innerW, ROW_TEXT_H, ALIGN_LEFT, TEXT_DIM, FontM)
			h:renderText(("%s / %s"):format(compact(Exchange.usedToday),
				compact(Exchange.dailyLimit)),
				PAD, ROW_LABEL, innerW, ROW_TEXT_H, ALIGN_RIGHT, TEXT, FontM)

			-- draw the empty track first, so it shows even at 0 used
			h:renderColor(PAD, RAIL_Y, innerW, RAIL_H, RAIL_BG)
			h:renderColor(PAD, RAIL_Y, innerW, 1, RAIL_EDGE)

			if used > 0 then
				h:renderColor(PAD, RAIL_Y, innerW * used, RAIL_H, RAIL_FILL)
			end
		end

		-- the panel advertises a rate, so it has to say how to act on it
		h:renderText("press " .. OPEN_KEY .. " to exchange",
			0, ROW_HINT, s.w, ROW_TEXT_H, ALIGN_CENTER, TEXT_DIM, FontM)

	end)

	Net.OnPacket(S.TICKER_OP, function(reader)
		Exchange.rate       = reader:dword()
		Exchange.usedToday  = reader:dword()
		Exchange.dailyLimit = reader:dword()
	end)

	local function askForRate()
		hud:show(true)
		Net.CreatePacket(S.TICKER_OP):send()
	end

	Event.on("ingame", askForRate)

	if Input.GameState() == Enums.GameState.IN_GAME then
		askForRate()
	end
end

