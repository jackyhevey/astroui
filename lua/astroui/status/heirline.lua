---AstroNvim Status Heirline Extensions
---
---Statusline related heirline specific extensions
---
---This module can be loaded with `local astro_heirline = require "astroui.status.heirline"`
---
---copyright 2023
---license GNU General Public License v3.0
---@class astroui.status.heirline
local M = {}

local hl = require "astroui.status.hl"
local provider = require "astroui.status.provider"
local status_utils = require "astroui.status.utils"

local buf_utils = require "astrocore.buffer"
local get_icon = require("astroui").get_icon

--- A helper function to get the type a tab or buffer is
---@param self table the self table from a heirline component function
---@param prefix? string the prefix of the type, either "tab" or "buffer" (Default: "buffer")
---@return string # the string of prefix with the type (i.e. "_active" or "_visible")
function M.tab_type(self, prefix)
  local tab_type = ""
  if self.is_active then
    tab_type = "_active"
  elseif self.is_visible then
    tab_type = "_visible"
  end
  return (prefix or "buffer") .. tab_type
end

local function cached_func(func, ...)
  local cached
  local args = { ... }
  return function(self)
    if cached == nil then cached = func(unpack(args)) end
    if type(cached) == "function" then return cached(self) end
    return cached
  end
end

--- Make a list of buffers, rendering each buffer with the provided component
---@param component table
---@return table
function M.make_buflist(component)
  local overflow_hl = cached_func(hl.get_attributes, "buffer_overflow", true)
  return require("heirline.utils").make_buflist(
    status_utils.surround(
      "tab",
      function(self)
        return {
          main = M.tab_type(self) .. "_bg",
          left = "tabline_bg",
          right = "tabline_bg",
        }
      end,
      { -- bufferlist
        init = function(self) self.tab_type = M.tab_type(self) end,
        on_click = { -- add clickable component to each buffer
          callback = function(_, minwid) vim.api.nvim_win_set_buf(0, minwid) end,
          minwid = function(self) return self.bufnr end,
          name = "heirline_tabline_buffer_callback",
        },
        { -- add buffer picker functionality to each buffer
          condition = function(self) return self._show_picker end,
          update = false,
          init = function(self)
            if not vim.tbl_get(self._picker_labels, self.label) then
              local bufname = provider.filename()(self)
              local label = bufname:sub(1, 1)
              local i = 2
              while label ~= " " and self._picker_labels[label] do
                if i > #bufname then break end
                label = bufname:sub(i, i)
                i = i + 1
              end
              self._picker_labels[label] = self.bufnr
              self.label = label
            end
          end,
          provider = function(self) return provider.str { str = self.label, padding = { left = 1, right = 1 } } end,
          hl = cached_func(hl.get_attributes, "buffer_picker"),
        },
        component, -- create buffer component
      },
      function(self) return buf_utils.is_valid(self.bufnr) end -- disable surrounding
    ),
    { provider = get_icon "ArrowLeft" .. " ", hl = overflow_hl },
    { provider = get_icon "ArrowRight" .. " ", hl = overflow_hl },
    function()
      vim.t.bufs = vim.tbl_filter(buf_utils.is_valid, vim.t.bufs or {})
      return vim.t.bufs
    end, -- use astronvim bufs variable
    false -- disable internal caching
  )
end

--- Alias to require("heirline.utils").make_tablist
function M.make_tablist(...) return require("heirline.utils").make_tablist(...) end

--- Run the buffer picker and execute the callback function on the selected buffer
---@param callback function with a single parameter of the buffer number
function M.buffer_picker(callback)
  local tabline = require("heirline").tabline
  -- if buflist then
  local prev_showtabline = vim.opt.showtabline:get()
  if prev_showtabline ~= 2 then vim.opt.showtabline = 2 end
  vim.cmd.redrawtabline()
  ---@diagnostic disable-next-line: undefined-field
  local buflist = vim.tbl_get(tabline, "_buflist", 1)
  if buflist then
    buflist._picker_labels = {}
    buflist._show_picker = true
    vim.cmd.redrawtabline()
    local char = vim.fn.getcharstr()
    local bufnr = buflist._picker_labels[char]
    if bufnr then callback(bufnr) end
    buflist._show_picker = false
  end
  if prev_showtabline ~= 2 then vim.opt.showtabline = prev_showtabline end
  vim.cmd.redrawtabline()
  -- end
end

--- Refresh heirline colors
function M.refresh_colors() require("heirline.utils").on_colorscheme(require("astroui").config.status.setup_colors) end

return M
