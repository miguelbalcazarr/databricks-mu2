--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================================
-- Protocol.lua - the wire contract for the Lua window channel.
--
-- There are two channels, carrying the same payload primitives and differing
-- only in what addresses a message:
--
--   windows   addressed by window id + action. Opened by setting win.visible,
--             used through net.send / net.on. This file describes it.
--   general   addressed by an opcode, for anything without a window of its own.
--             Net.CreatePacket / Net.OnPacket, server side Net.Send / Net.On.
--
-- Registry.lua owns the ids (which window). This file owns the protocol: one
-- table per system, holding its actions, its result codes and its limits. A
-- system's constants never live outside its own table, so two windows can never
-- disagree about what a number means. The GS mirror is
-- Data\Plugins\LuaAPI\Defines\UIProtocol.lua and MUST stay value-for-value
-- identical - change one, change the other.
--
--   local P = require("Protocol")
--   local S = P.MySystem
--   net.send(S.id, S.BUY):byte(kind):dword(count):send()
--   net.on(S.id, S.STATE, function(result, reader) ... end)
--   if result == S.RESULT.NO_FUNDS then ... end
--
-- Rules shared by both channels (hence not repeated per system):
--   * the ANS result travels as an unsigned BYTE and 0 always means success
--   * an open request is granted only on result 0
--   * payload primitives, all little-endian:
--       byte 1  word 2  dword 4  qword 8      unsigned integers
--       float 4  double 8                     IEEE
--       text                                  WORD length + raw bytes
--       str                                   fixed width, zero padded
--     float holds only ~7 significant digits - reach for double, or for
--     dword/qword when the value is a whole number. qword is exact to 2^53
--     here, because a client Lua number is a double; item serials use the full
--     64 bits, so send those as two dwords or as text.
-- ============================================================================

local R = require("Registry")

local P = {}

-- ---- shared game enum, not a per-window protocol value ----------------------
-- Currency ids as used server-wide by CoinMng and by every ItemBank.xml
-- *CoinType attribute. The XML writes -1 for "free"; on the wire it travels as
-- an unsigned byte, hence FREE = 255.
P.COIN = {
	ZEN    = 0,
	WCOIN  = 1,
	GOBLIN = 2,
	RUUD   = 3,
	FREE   = 255,
}

-- ============================================================================
-- Coin Exchange - converts WCoin to Ruud at a fixed rate.
--
-- C->S  CONVERT   dword amount
--
-- S->C  RATE      dword rate, dword wcoin, dword ruud
-- S->C  HISTORY   byte count, then per entry: text date, dword spent, dword gained
--
-- The current rate also travels on the general channel (opcode below), so the
-- HUD ticker has it without the window being open.
-- ============================================================================
P.Exchange = {
	id = R.win.exchange,

	RATE    = 1,
	CONVERT = 2,
	HISTORY = 3,

	MIN = 100,
	MAX = 100000,

	TICKER_OP = 110,   -- general channel: rate + today's allowance

	RESULT = {
		OK         = 0,
		BAD_AMOUNT = 10,
		NO_FUNDS   = 11,
		LIMIT      = 12,
	},
}

return P
