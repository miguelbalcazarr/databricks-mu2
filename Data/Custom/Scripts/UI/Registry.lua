--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================
-- Registry.lua : the SINGLE, CENTRAL source of truth for shared ids across all
-- client UI scripts. require() it from any script and refer to everything by name;
-- because require() is cached, every script gets the SAME tables, so a name
-- defined here resolves identically everywhere.
--
--   local R = require("Registry")
--   local win = ui.Window{ id = R.win.demo, skin = { slot = R.slot.frame, ... } }
--   local existing = UI.GetWindow(R.win.demo)   -- reference it from another script
--
-- Two kinds of pools:
--   R.win  - window ids (ui.NewWindow / UI.GetWindow)
--   R.slot - texture slots (UI.LoadImage); reuse a name to SHARE one atlas
-- A name auto-allocates a stable integer on first use, OR you pin it explicitly
-- below (recommended for anything referenced across scripts or by the server).
-- ============================================================

local ui = require("UI")

local R = {
	win  = ui.newIdSet(1, nil, "window"),        -- window ids   (1, 2, 3, ...)
	slot = ui.newIdSet(0, 512, "texture slot"),  -- UI.LoadImage slots (0..511)
}

-- ---- window ids -------------------------------------------------------------
R.win.demo         = 1
R.win.uiplacement  = 2   -- UIPlacement.lua, the placement helper
R.win.exchange     = 3   -- Coin Exchange window
R.win.exchangehud  = 4   -- its HUD ticker
-- R.win.inventory = 5

-- ---- texture atlases (one slot per named bitmap) ----------------------------
R.slot.frame    = 0   -- Custom\Interface\UI\CommandWindowFrame.tga (window + buttons + bar)
R.slot.macros   = 2   -- Custom\Interface\UI\Macros.tga (UIMsgBox buttons + decal)

-- Point several scripts at one slot name to share a bitmap: first load wins, so
-- load order does not matter (Demo and Coin Exchange share R.slot.frame).

return R
