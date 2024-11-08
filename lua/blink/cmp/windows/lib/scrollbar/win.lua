--- Manages creating/updating scrollbar gutter and thumb windows

--- @class blink.cmp.ScrollbarWin
--- @field enable_gutter boolean
--- @field thumb_win? number
--- @field gutter_win? number
--- @field buf? number
---
--- @field new fun(opts: blink.cmp.ScrollbarConfig): blink.cmp.ScrollbarWin
--- @field is_visible fun(self: blink.cmp.ScrollbarWin): boolean
--- @field show_thumb fun(self: blink.cmp.ScrollbarWin, geometry: blink.cmp.ScrollbarGeometry)
--- @field show_gutter fun(self: blink.cmp.ScrollbarWin, geometry: blink.cmp.ScrollbarGeometry)
--- @field hide_thumb fun(self: blink.cmp.ScrollbarWin)
--- @field hide_gutter fun(self: blink.cmp.ScrollbarWin)
--- @field hide fun(self: blink.cmp.ScrollbarWin)
--- @field _make_win fun(self: blink.cmp.ScrollbarWin, geometry: blink.cmp.ScrollbarGeometry, hl_group: string): number

local chars_l = {
  [1] = '▏',
  [2] = '▎',
  [3] = '▍',
  [4] = '▌',
  [5] = '▋',
  [6] = '▊',
  [7] = '▉',
  [8] = '█',
}
local chars_r = {
  [1] = '▕',
  [2] = '🮇',
  [3] = '🮈',
  [4] = '▐',
  [5] = '🮉',
  [6] = '🮊',
  [7] = '🮋',
  [8] = '█',
}

local chars_t = {
  [1] = '▔',
  [2] = '🮂',
  [3] = '🮃',
  [4] = '▀',
  [5] = '🮄',
  [6] = '🮅',
  [7] = '🮆',
  [8] = '█',
}

local chars_b = {
  [1] = '▁',
  [2] = '▂',
  [3] = '▃',
  [4] = '▄',
  [5] = '▅',
  [6] = '▆',
  [7] = '▇',
  [8] = '█',
}

-- Function to get the nearest character based on fractional block
local function get_partial_char(fraction, chars)
  if fraction >= 7 / 8 then return chars[8] end
  if fraction >= 6 / 8 then return chars[7] end
  if fraction >= 5 / 8 then return chars[6] end
  if fraction >= 4 / 8 then return chars[5] end
  if fraction >= 3 / 8 then return chars[4] end
  if fraction >= 2 / 8 then return chars[3] end
  if fraction >= 1 / 8 then return chars[2] end
  return chars[1]
end

-- Function to calculate scrollbar with partial blocks
local function calculate_scrollbar(window_height, buffer_height, scrolltop, horizontal)
  local scrollbar_size = math.max(1, math.floor(window_height * (window_height / buffer_height)))
  local scroll_range = buffer_height - window_height

  -- Calculate top and bottom positions for the scrollbar
  local relative_scroll_position = (scrolltop / scroll_range) * (window_height - scrollbar_size)
  local top_position = math.floor(relative_scroll_position)
  local bottom_position = math.floor(relative_scroll_position + scrollbar_size - 1)

  -- Calculate partial fractions for the top and bottom characters
  local top_fraction = relative_scroll_position % 1
  local bottom_fraction = (relative_scroll_position + scrollbar_size) % 1

  -- Get the appropriate characters for top and bottom partial blocks
  local top_char = get_partial_char(top_fraction, chars_t)
  local bottom_char = get_partial_char(1 - bottom_fraction, chars_b)

  -- Number of full blocks between the top and bottom partial blocks
  local full_blocks = bottom_position - top_position - 1

  return top_char, bottom_char, math.max(0, full_blocks), top_position
end

local function render_bar(window_height, buffer_height, scrolltop)
  local top_char, bottom_char, full_blocks, top = calculate_scrollbar(window_height, buffer_height, scrolltop)

  local bar = {}

  for _ = 1, top do
    table.insert(bar, '')
  end

  table.insert(bar, bottom_char)

  for _ = 1, full_blocks do
    table.insert(bar, chars_l[8])
  end

  table.insert(bar, top_char)

  return bar
end

local scrollbar_win = {}

function scrollbar_win.new(opts) return setmetatable(opts, { __index = scrollbar_win }) end

function scrollbar_win:is_visible() return self.thumb_win ~= nil and vim.api.nvim_win_is_valid(self.thumb_win) end

function scrollbar_win:show_thumb(geometry)
  -- create window if it doesn't exist
  -- if self.thumb_win == nil or not vim.api.nvim_win_is_valid(self.thumb_win) then
  --   self.thumb_win = self:_make_win(geometry, 'BlinkCmpScrollBarThumb')
  -- end
  --
  -- -- update with the geometry
  -- local thumb_existing_config = vim.api.nvim_win_get_config(self.thumb_win)
  -- local thumb_config = vim.tbl_deep_extend('force', thumb_existing_config, geometry)
  -- vim.api.nvim_win_set_config(self.thumb_win, thumb_config)
end

function scrollbar_win:show_gutter(geometry, buf_height)
  if not self.enable_gutter then return end

  -- create window if it doesn't exist
  if self.gutter_win == nil or not vim.api.nvim_win_is_valid(self.gutter_win) then
    self.gutter_win = self:_make_win(geometry, 'BlinkCmpScrollBarGutter')
  end

  -- update with the geometry
  local gutter_existing_config = vim.api.nvim_win_get_config(self.gutter_win)
  local gutter_config = vim.tbl_deep_extend('force', gutter_existing_config, geometry)
  vim.api.nvim_win_set_config(self.gutter_win, gutter_config)

  local gutter_buf = vim.api.nvim_win_get_buf(self.gutter_win)
  local gutter_bar = render_bar(geometry.height, buf_height.buf_height, buf_height.topline)

  vim.api.nvim_buf_set_lines(gutter_buf, 0, -1, false, gutter_bar)
end

function scrollbar_win:hide_thumb()
  if self.thumb_win and vim.api.nvim_win_is_valid(self.thumb_win) then vim.api.nvim_win_close(self.thumb_win, true) end
end

function scrollbar_win:hide_gutter()
  if self.gutter_win and vim.api.nvim_win_is_valid(self.gutter_win) then
    vim.api.nvim_win_close(self.gutter_win, true)
  end
end

function scrollbar_win:hide()
  self:hide_thumb()
  self:hide_gutter()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then vim.api.nvim_buf_delete(self.buf, { force = true }) end
end

function scrollbar_win:_make_win(geometry, hl_group)
  if self.buf == nil or not vim.api.nvim_buf_is_valid(self.buf) then self.buf = vim.api.nvim_create_buf(false, true) end

  local win_config = vim.tbl_deep_extend('force', geometry, {
    style = 'minimal',
    focusable = false,
    noautocmd = true,
  })
  local win = vim.api.nvim_open_win(self.buf, false, win_config)
  vim.api.nvim_set_option_value('winhighlight', 'Normal:' .. hl_group .. ',EndOfBuffer:' .. hl_group, { win = win })
  return win
end

return scrollbar_win
