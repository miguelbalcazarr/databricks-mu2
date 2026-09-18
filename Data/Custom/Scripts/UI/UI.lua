--═══════════════════════════════════════════════════════════════
--== INTERNATIONAL GAMING CENTER NETWORK
--== www.igcn.mu
--== (C) 2010-2026 IGC-Network (R)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--== File is a part of IGCN Group MuOnline Server files.
--═══════════════════════════════════════════════════════════════

-- ============================================================
-- UI.lua : declarative UI helper on top of the client Lua UI primitives.
--   local ui = require("UI")   -- LOWERCASE local: `UI` is a client global table
-- Pure Lua over UI.NewWindow / window:add* / :renderText. No engine changes
-- except the controls/scroll the client already exposes.
--
-- Windows:
--   ui.Window{ id=, center=true (or x=,y=), w=,
--              height=fixed  OR  minHeight=, maxHeight=,   -- content-driven
--              scroll=true,                                -- pixel-clipped scroll on overflow
--              scrollbar=true, scrollbarWidth=12,          -- interactive bar (arrows+thumb)
--              scrollbarMargin=16,                         -- inset bar off the frame border
--              scrollbarPad={top,bottom},                  -- inset bar from viewport ends
--              scrollbarAutoHide=true,                     -- show bar only while hovering
--              contentFullWidth=false,                     -- center over full width vs up-to-bar
--              contentTop=, title=, titleColor=, drag={x,y,w,h}, skin=frameSkin,
--              mode="hud"|"window",                        -- render tier
--              clickThrough=false }                        -- pass clicks to the world
--   ui.Window(id, ui.CENTER, w, h [,title])               -- positional shorthand
--   ui.Window(id, x, y, w, h [,title])
--
-- Frame skin (vertical 3-slice, tiled middle):
--   skin = { slot=, path="Custom\\...\\Frame.tga",
--            top={sx,sy,sw,sh}, middle={sx,sy,sw,sh}, bottom={sx,sy,sw,sh},
--            topH=, midH=, botH= }   -- optional render heights (default = source sh)
--
-- Layout groups auto-position children (no explicit x/y), auto-assign ids:
--   local col = win:Column{ top=, padding=, spacing=, align="left|center|right" }
--   col:Label(text, opts) / col:Button(text, opts) / col:TextInput(opts)
--   Label opts: w=, h=, align=, color=, scale=,
--               slide=false (no hover scroll), bold=true
--   Button opts: w=, h=, color=, scale=, onClick=fn
--               btn:setImage(ui.STATE.NORMAL|INACTIVE|HOVER|PRESSED, slot, sx,sy,sw,sh)
--   TextInput opts: w=, h=, maxLen=, minLen=, minBytes=, maxBytes=, color=,
--               backColor=,
--               align=,
--               numeric=true (digits only), allow="[%a%d_]" (Lua pattern, one
--               character at a time), maxValue=, onEnter=fn,
--               placeholder="Name", placeholderColor=, placeholderAlign=4,
--               ime=false (no IME composition in this field),
--               strictCodePage=false (accept characters the client's codepage
--               cannot hold - they leave as '?'; on by default, which refuses
--               them and logs why)
-- ============================================================

local M = {}
M.CENTER = "__center__"

-- Button states for btn:setImage(state, ...) and btn.state. A state with no
-- image of its own falls back to NORMAL.
M.STATE = {
	NORMAL   = 0,
	INACTIVE = 1,
	HOVER    = 2,
	PRESSED  = 3,
}

-- ============================================================================
-- Anchoring. x/y are on a fixed 640x480 canvas (resolution independent), but the
-- rendered size is w * UI.Scale() - so pinning to an edge needs the SCALED size
-- subtracted. anchor() does that for you.
--
--   ui.Window{ anchor = "topright", margin = { 8, 8 }, w = 120, height = 60 }
--   local x, y = ui.anchor(120, 60, "bottom", 0, 12)
-- ============================================================================
local ANCHOR_X = {
	topleft = 0, left = 0, bottomleft = 0,
	top = 0.5, center = 0.5, bottom = 0.5,
	topright = 1, right = 1, bottomright = 1,
}

local ANCHOR_Y = {
	topleft = 0, top = 0, topright = 0,
	left = 0.5, center = 0.5, right = 0.5,
	bottomleft = 1, bottom = 1, bottomright = 1,
}

-- dx/dy are margins measured inward from the anchored edge
function M.anchor(w, h, where, dx, dy)
	local fx = ANCHOR_X[where]

	if fx == nil then
		error(("ui: unknown anchor '%s'"):format(tostring(where)))
	end

	local fy = ANCHOR_Y[where]
	local scale = UI.Scale()
	local sw, sh = UI.ScreenWidth(), UI.ScreenHeight()
	local ww, wh = w * scale, h * scale

	return (sw - ww) * fx + (dx or 0) * (1 - 2 * fx),
	       (sh - wh) * fy + (dy or 0) * (1 - 2 * fy)
end

-- ============================================================
-- newIdSet : factory for a named id pool. A name auto-allocates a stable integer
-- on first access; the same name always returns the same id. You can also pin an
-- explicit value (name = n). Define your pools in one place - see Registry.lua:
--   local R = require("Registry")
--   ui.Window{ id = R.win.demo, skin = { slot = R.slot.frame, ... } }
-- ============================================================
function M.newIdSet(startAt, maxCount, label)
	local names = {}
	local nextId = startAt or 0
	return setmetatable({}, {
		__index = function(_, name)
			local id = names[name]
			if id == nil then
				if maxCount and (nextId - (startAt or 0)) >= maxCount then
					error(("ui: %s pool exhausted at '%s'"):format(label or "id", tostring(name)))
				end
				id = nextId
				names[name] = id
				nextId = nextId + 1
			end
			return id
		end,
		__newindex = function(_, name, val)
			names[name] = val
			if type(val) == "number" and val >= nextId then nextId = val + 1 end
		end,
		__names = names,
	})
end

-- Every name handed out by a pool, as { name = id }.
function M.idNames(set)
	local mt = getmetatable(set)
	return mt and mt.__names or {}
end

-- Draws a box cut from a texture without smearing its corners: the four corners
-- are copied 1:1, the edges and the middle stretch to fill. b is the corner size.
function M.nineSlice(h, slot, dx, dy, dw, dh, sx, sy, sw, sh, b)
	local x0, x1, x2 = dx, dx + b, dx + dw - b
	local y0, y1, y2 = dy, dy + b, dy + dh - b
	local mw, mh     = dw - 2 * b, dh - 2 * b
	local ax0, ax1, ax2 = sx, sx + b, sx + sw - b
	local ay0, ay1, ay2 = sy, sy + b, sy + sh - b
	local amw, amh      = sw - 2 * b, sh - 2 * b
	h:renderImage(slot, x0, y0, b, b, ax0, ay0, b, b)
	h:renderImage(slot, x2, y0, b, b, ax2, ay0, b, b)
	h:renderImage(slot, x0, y2, b, b, ax0, ay2, b, b)
	h:renderImage(slot, x2, y2, b, b, ax2, ay2, b, b)
	h:renderImage(slot, x1, y0, mw, b, ax1, ay0, amw, b)
	h:renderImage(slot, x1, y2, mw, b, ax1, ay2, amw, b)
	h:renderImage(slot, x0, y1, b, mh, ax0, ay1, b, amh)
	h:renderImage(slot, x2, y1, b, mh, ax2, ay1, b, amh)
	h:renderImage(slot, x1, y1, mw, mh, ax1, ay1, amw, amh)
end

-- Vertical 3-slice frame: top cap, repeated (tiled) middle, bottom cap.
function M.renderFrame(h, w, winH, skin)
	if not skin._loaded then
		skin._loaded = UI.LoadImage(skin.slot, skin.path)
	end

	if not skin._loaded then
		h:renderColor(0, 0, w, winH, RGBA(10, 10, 30, 220))
		return
	end

	local top, mid, bot = skin.top, skin.middle, skin.bottom
	local topH = skin.topH or top[4]
	local botH = skin.botH or bot[4]
	local midH = skin.midH or mid[4]

	h:renderImage(skin.slot, 0, 0, w, topH, top[1], top[2], top[3], top[4])
	h:renderImage(skin.slot, 0, winH - botH, w, botH, bot[1], bot[2], bot[3], bot[4])

	local y = topH
	local bandEnd = winH - botH
	while y < bandEnd do
		local tileH = math.min(midH, bandEnd - y)
		local srcH = mid[4] * (tileH / midH)
		h:renderImage(skin.slot, 0, y, w, tileH, mid[1], mid[2], mid[3], srcH)
		y = y + tileH
	end
end

local Window = {}
Window.__index = Window
local Group = {}
Group.__index = Group

local function newWindow(fields)
	local handle = UI.NewWindow(fields.id, fields.x, fields.y, fields.w, fields.h)
	if not handle then return nil end

	local self = setmetatable({
		h_win = handle, id = fields.id, w = fields.w, h = fields.h,
		title = fields.title, centered = fields.centered,
		_id = 1, _bg = nil,
		_titleColor = fields.titleColor or RGBA(255, 255, 255, 255),
		_contentBottom = 0,
		fixedHeight = fields.fixedHeight,
		minHeight = fields.minHeight, maxHeight = fields.maxHeight,
		_expandable = fields.expandable,
		_fitPad = fields.padBottom or 12,
		_skin = nil, _fitted = false,
		_scroll = fields.scroll or false,
		_scrollbar = fields.scrollbar or false,
		_scrollbarW = fields.scrollbarWidth or 12,
		_scrollbarMargin = fields.scrollbarMargin or 6,
		_contentFullWidth = fields.contentFullWidth or false,
		_contentTop = fields.contentTop or 28,
		_titleY = fields.titleY or 7,
		_headerH = fields.headerH,
		_anchor = fields.anchor,
		_marginX = fields.marginX, _marginY = fields.marginY,
	}, Window)

	handle.render = function(_)
		if self._expandable and not self._fitted then self:fit(self._fitPad) end
		if self._bg then self._bg(self, handle) end
		-- header/title chrome: drawn unclipped, above the (scrollable) content
		if self._headerH then
			-- thin separator line under the header section
			handle:renderColor(6, self._headerH - 1, self.w - 12, 1, RGBA(0, 0, 0, 150))
		end
		if self.title then
			handle:renderText(self.title, 0, self._titleY, self.w, 16, 4, self._titleColor, 1.0)
		end
	end

	return self
end

local function windowFromTable(o)
	local w = o.w or 260
	local fixedH = o.height
	local minH = o.minHeight
	local maxH = o.maxHeight
	local h0 = fixedH or minH or 100
	local x, y, centered

	local margin = o.margin or {}

	if o.center then
		x, y = UI.Center(w, h0)
		centered = true
	elseif o.anchor then
		x, y = M.anchor(w, h0, o.anchor, margin[1], margin[2])
	else
		x, y = o.x or 0, o.y or 0
	end

	-- Header section: reserved fixed strip at the top. Content (and scroll) live
	-- below it. The frame's top cap is stretched to the header height.
	local headerH = o.header
	local contentTop = o.contentTop or headerH or 28
	local titleY = o.titleY or (headerH and (headerH * 0.5 - 8)) or 7
	if headerH and o.skin then o.skin.topH = headerH end

	local self = newWindow{
		id = o.id, x = x, y = y, w = w, h = h0,
		title = o.title, titleColor = o.titleColor, centered = centered,
		fixedHeight = (fixedH ~= nil),
		minHeight = minH, maxHeight = maxH,
		expandable = (fixedH == nil) and (minH ~= nil or maxH ~= nil),
		padBottom = o.padBottom,
		scroll = o.scroll, contentTop = contentTop,
		scrollbar = o.scrollbar, scrollbarWidth = o.scrollbarWidth,
		scrollbarMargin = o.scrollbarMargin, contentFullWidth = o.contentFullWidth,
		titleY = titleY, headerH = headerH,
		anchor = o.anchor, marginX = margin[1], marginY = margin[2],
	}

	if not self then return nil end

	-- Render tier. "hud" draws with the game's own HUD: it shows without asking
	-- the server and ESC does not close it. clickThrough passes clicks to the world.
	if o.mode then self.h_win.mode = o.mode end
	if o.clickThrough ~= nil then self.h_win.clickThrough = o.clickThrough end

	if o.skin then self:frameSkin(o.skin) end
	if o.drag then self.h_win:setDragArea(o.drag[1], o.drag[2], o.drag[3], o.drag[4]) end

	if o.scrollbar then
		self.h_win:setScrollbar(true, self._scrollbarW)
		-- push the bar off the decorative frame border + optional viewport insets
		local padTop = o.scrollbarPadTop or (o.scrollbarPad and o.scrollbarPad[1])
		local padBottom = o.scrollbarPadBottom or (o.scrollbarPad and o.scrollbarPad[2])
		self.h_win:setScrollbarMargin(self._scrollbarMargin, padTop, padBottom)
		if o.scrollbarAutoHide then self.h_win:setScrollbarAutoHide(true) end
		-- by default the bar only appears when the content overflows the viewport;
		-- scrollbarAlways = true keeps the track + arrows there permanently
		if o.scrollbarAlways then self.h_win:setScrollbarAlwaysVisible(true) end
		-- contentFullWidth: center over the whole window (content may sit under the
		-- bar) and stop clipping to the bar's left edge. Default = reach up to the bar.
		if self._contentFullWidth then self.h_win:setContentClipRight(false) end
	end

	return self
end

-- Creates a window. Pass the options table described at the top of this file, or
-- the short form - ui.Window(id, x, y, w, h [,title]) and ui.Window(id, ui.CENTER,
-- w, h [,title]) when all you need is a plain box.
function M.Window(id, a, b, c, d, e)
	if type(id) == "table" then
		return windowFromTable(id)
	end

	local x, y, w, h, title, centered
	if a == M.CENTER then
		w, h, title, centered = b, c, d, true
		x, y = UI.Center(w, h)
	else
		x, y, w, h, title = a, b, c, d, e
	end

	return newWindow{
		id = id, x = x, y = y, w = w, h = h, title = title, centered = centered,
		fixedHeight = false, expandable = false,
	}
end

-- Chainable helpers on an existing window (isVisible/nextId return their value
-- instead). handle() is the raw window, background(fn) draws behind the content,
-- show(true) on a floating window only requests it - the server decides. Skin
-- buttons only once textureReady() is true.
function Window:handle() return self.h_win end
function Window:background(fn) self._bg = fn; return self end
function Window:titleColor(c) self._titleColor = c; return self end
function Window:setDragArea(a, b, c, d) self.h_win:setDragArea(a, b, c, d); return self end
function Window:show(v) self.h_win.visible = (v ~= false); return self end
function Window:isVisible() return self.h_win.visible end
function Window:bringToFront() self.h_win:bringToFront(); return self end
function Window:nextId() local i = self._id; self._id = i + 1; return i end
function Window:textureReady() return self._skin ~= nil and self._skin._loaded == true end

-- Dresses the window in a frame cut from a texture - top cap, tiled middle,
-- bottom cap (the skin table is described at the top). The atlas loads on the
-- first render pass, so a shared slot shows its fallback colour for one frame.
function Window:frameSkin(skin)
	self._skin = skin
	self:background(function(s, h) M.renderFrame(h, s.w, s.h, skin) end)
	return self
end

-- Fit height to content (clamped to [minHeight, maxHeight]); wire up native
-- pixel-clipped scroll when scroll=true and the content overflows.
function Window:fit(bottomPad)
	if self.fixedHeight then self._fitted = true; return self end
	bottomPad = bottomPad or self._fitPad or 12
	local target = self._contentBottom + bottomPad

	if self.minHeight and target < self.minHeight then target = self.minHeight end
	if self.maxHeight and target > self.maxHeight then target = self.maxHeight end

	self.h = target
	self.h_win.height = target

	-- the height just changed, so an edge-pinned window has to be re-placed
	if self.centered then
		local nx, ny = UI.Center(self.w, target)
		self.h_win.x = nx
		self.h_win.y = ny
	elseif self._anchor then
		local nx, ny = M.anchor(self.w, target, self._anchor, self._marginX, self._marginY)
		self.h_win.x = nx
		self.h_win.y = ny
	end

	if self._scroll then
		local viewTop = self._contentTop
		local viewBottom = target - bottomPad
		self.h_win:setScroll(viewTop, viewBottom)
		self.h_win:setContentHeight((self._contentBottom + bottomPad) - viewTop)
	end

	self._fitted = true
	return self
end

-- Layout groups. They place children for you - a Column stacks them downwards, a
-- Row lines them up side by side - so Label/Button/TextInput never take x/y.
function Window:Column(opts) return M._group(self, "v", opts) end
function Window:Row(opts)    return M._group(self, "h", opts) end

function M._group(win, dir, opts)
	opts = opts or {}
	local pad = opts.padding or 12
	local start = opts.top or opts.y or pad
	local px = opts.x or pad
	-- barLeft is where usable content stops so it clears the scrollbar strip;
	-- contentFullWidth opts out and lets content use the whole width.
	local reserves = win._scroll and win._scrollbar and not win._contentFullWidth
	local barLeft = reserves and (win.w - win._scrollbarW - win._scrollbarMargin) or (win.w - pad)
	return setmetatable({
		win = win, dir = dir,
		x = px,
		y = start,
		w = opts.w or (barLeft - px),   -- max element width: from px up to the bar
		barLeft = barLeft,
		boxW = win.w,
		pad = px,
		spacing = opts.spacing or 6,
		align = opts.align or "left",
		cursor = start,
	}, Group)
end

function Group:_place(w, h)
	local x, y
	if self.dir == "v" then
		y = self.cursor
		if self.align == "center" then
			x = self.boxW / 2 - w / 2                -- centre on the panel/window box
			local maxX = self.barLeft - 2 - w         -- but keep clear of the scrollbar
			if x > maxX then x = maxX end
			if x < self.pad then x = self.pad end
		elseif self.align == "right" then
			x = self.barLeft - 2 - w
			if x < self.pad then x = self.pad end
		else
			x = self.x
		end
		self.cursor = self.cursor + h + self.spacing
	else
		x = self.cursor
		y = self.y
		self.cursor = self.cursor + w + self.spacing
	end
	if y + h > self.win._contentBottom then self.win._contentBottom = y + h end
	return x, y
end

-- A line of text. Scrolls and clips together with the rest of the window.
function Group:Label(text, opts)
	opts = opts or {}
	local w = opts.w or self.w
	local h = opts.h or 16
	local x, y = self:_place(w, h)
	local lbl = self.win.h_win:addLabel(self.win:nextId(), x, y, w, h)
	lbl.text = text or ""
	lbl:setAlign(opts.align or 4)
	if opts.color then lbl:setColor(opts.color) end
	if opts.scale then lbl:setScale(opts.scale) end
	-- A label slides its text sideways on hover when it overflows (on by default).
	-- Pass slide=false on anything that should sit still.
	if opts.slide ~= nil then lbl.slide = opts.slide end
	if opts.bold then lbl.bold = true end
	return lbl
end

-- A button. opts.onClick runs when it is pressed; call setImage() on what comes
-- back to give it a bitmap instead of the default look.
function Group:Button(text, opts)
	opts = opts or {}
	local w = opts.w or 120
	local h = opts.h or 26
	local x, y = self:_place(w, h)
	local btn = self.win.h_win:addButton(self.win:nextId(), x, y, w, h)
	btn:setText(text, opts.color or RGBA(255, 255, 255, 255), opts.scale or 1.0)
	if opts.onClick then btn.click = opts.onClick end
	return btn
end

-- minLen/minBytes are not keystroke filters (a field is "too short" mid-typing).
-- onEnter stays quiet until they are met; ui.textOk(input) checks the same rule
-- anywhere else you submit from.
local minLens = setmetatable({}, { __mode = "k" })
local minBytes = setmetatable({}, { __mode = "k" })

-- minLen counts characters, minBytes counts what the text costs in the client's
-- codepage. Pair minBytes with maxBytes and minLen with maxLen - mixing the two
-- units is how you end up with a field that can never satisfy both ends.
function M.textOk(input)
	if input == nil then
		return false
	end

	return M.textLen(input.text) >= (minLens[input] or 0)
		and input.bytesUsed >= (minBytes[input] or 0)
end

-- Encoding. Packets carry bytes untouched, so convert where a value has to match
-- the game's structures or a database column - not everywhere:
--   input.textCodePage -> the field's text in the client's codepage
--   UI.ToCodePage(s)   -> same for any string, plus a 'lossy' flag
--   UI.FromCodePage(s) -> back to UTF-8, for text that came from the game or DB
--   UI.CodePage()      -> the codepage number in force

-- Characters, not bytes. #s counts BYTES, so a six-character Chinese name
-- reads as 18 and a byte-based length check rejects it. Anything a player
-- typed goes through here.
function M.textLen(s)
	s = tostring(s or "")
	local n = 0

	for i = 1, #s do
		local b = s:byte(i)

		-- 128..191 are continuation bytes: they belong to the character before
		if b < 128 or b > 191 then
			n = n + 1
		end
	end

	return n
end

-- A single-line field the player types into. Read .text off the returned control.
-- maxLen (characters), maxBytes (size once converted to the client's codepage -
-- what has to fit a varchar(10) or char[10]) and numeric are all enforced per
-- keystroke, so the field can never hold a value that breaks them.
function Group:TextInput(opts)
	opts = opts or {}
	local w = opts.w or self.w
	local h = opts.h or 18
	local x, y = self:_place(w, h)
	local input = self.win.h_win:addTextInput(self.win:nextId(), x, y, w, h, opts.maxLen or 32)
	if opts.backColor then input:setBackColor(opts.backColor) end
	if opts.color then input:setColor(opts.color) end
	if opts.numeric then input.numeric = true end
	if opts.allow then input.allow = opts.allow end
	if opts.placeholder then input.placeholder = opts.placeholder end
	if opts.placeholderColor then input.placeholderColor = opts.placeholderColor end
	if opts.placeholderAlign then input.placeholderAlign = opts.placeholderAlign end
	if opts.ime ~= nil then input.ime = opts.ime end
	if opts.maxValue then input.maxValue = opts.maxValue end
	if opts.maxBytes then input.maxBytes = opts.maxBytes end
	if opts.strictCodePage ~= nil then input.strictCodePage = opts.strictCodePage end
	if opts.align then input.align = opts.align end
	if opts.minLen then minLens[input] = opts.minLen end
	if opts.minBytes then minBytes[input] = opts.minBytes end

	if opts.onEnter then
		local fn = opts.onEnter
		input.onEnter = function(...)
			if M.textOk(input) then
				return fn(...)
			end
		end
	end

	return input
end

-- ============================================================
-- ScrollPanel : a scrollable container placed inside a window (or another panel).
-- Its scrollbar is per-panel and independently stylable (colours or textures),
-- so different lists/tables in the same window can each look different.
--
--   local p = win:Panel{ id=, x=, y=, w=, h=,
--       back = RGBA(..),                 -- optional panel fill/frame
--       scrollbar = true, scrollbarWidth = 12, scrollbarMargin = 6,
--       scrollbarPad = {top,bottom}, scrollbarAutoHide = true,
--       contentFullWidth = false,
--       colors = { track=, arrow=, arrowPressed=, thumb=, thumbDrag=, glyph=, glyphPressed= },
--       skin   = { slot=SLOT,               -- reuse an already-loaded atlas (e.g. the window's)
--                  up={sx,sy,sw,sh}, down={..}, upPressed={..}, downPressed={..},
--                  thumb={..}, thumbTop={..}, thumbBot={..}, track={..} } }
--       -- pieces may also carry their own slot as {slot,sx,sy,sw,sh} to mix atlases
--   local col = p:Column{ ... };  col:Button(...) ...
--   p:fit()   -- sets contentHeight from the laid-out content (enables scroll on overflow)
-- The Group engine reuses .w / ._contentBottom / :nextId() / .h_win, so Column/Row
-- work exactly as they do on a window.
-- ============================================================
local Panel = {}
Panel.__index = Panel

function M._panel(host, opts)
	opts = opts or {}
	local id = opts.id or host:nextId()
	local x = opts.x or 0
	local y = opts.y or 0
	local w = opts.w or (host.w - x - 12)
	local h = opts.h or 100
	local handle = host.h_win:addScrollPanel(id, x, y, w, h)
	if not handle then return nil end

	local self = setmetatable({
		h_win = handle, id = id, w = w, h = h,
		_id = 1, _contentBottom = 0,
		_scroll = true,                                 -- a panel's viewport is its rect
		_scrollbar = opts.scrollbar or false,
		_scrollbarW = opts.scrollbarWidth or 12,
		_scrollbarMargin = opts.scrollbarMargin or 6,
		_contentFullWidth = opts.contentFullWidth or false,
		_fitPad = opts.padBottom or 8,
	}, Panel)

	if opts.back then handle:setBackColor(opts.back) end

	if opts.scrollbar then
		handle:setScrollbar(true, self._scrollbarW)
		local padTop = opts.scrollbarPadTop or (opts.scrollbarPad and opts.scrollbarPad[1])
		local padBottom = opts.scrollbarPadBottom or (opts.scrollbarPad and opts.scrollbarPad[2])
		handle:setScrollbarMargin(self._scrollbarMargin, padTop, padBottom)
		if opts.scrollbarAutoHide then handle:setScrollbarAutoHide(true) end
		if opts.scrollbarAlways then handle:setScrollbarAlwaysVisible(true) end
		if self._contentFullWidth then handle:setContentClipRight(false) end
		if opts.scrollStep then handle:setScrollStep(opts.scrollStep) end
		if opts.colors then handle:setScrollbarColors(opts.colors) end
		if opts.skin then handle:setScrollbarSkin(opts.skin) end
	end

	return self
end

function Window:Panel(opts) return M._panel(self, opts) end
function Panel:Panel(opts)  return M._panel(self, opts) end   -- nested panels

-- Panel helpers - the subset of the window's that a panel uses.
function Panel:handle() return self.h_win end
function Panel:nextId() local i = self._id; self._id = i + 1; return i end
function Panel:show(v) self.h_win.visible = (v ~= false); return self end
function Panel:Column(opts) return M._group(self, "v", opts) end
function Panel:Row(opts)    return M._group(self, "h", opts) end

-- Enable scrolling by publishing the laid-out content height. Overflow past the
-- panel's own height scrolls (with the panel's scrollbar if one was requested).
function Panel:fit(bottomPad)
	bottomPad = bottomPad or self._fitPad or 8
	self.h_win:setContentHeight(self._contentBottom + bottomPad)
	return self
end

return M
