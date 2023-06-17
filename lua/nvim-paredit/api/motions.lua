local traversal = require("nvim-paredit.utils.traversal")
local common = require("nvim-paredit.utils.common")
local ts = require("nvim-treesitter.ts_utils")
local langs = require("nvim-paredit.lang")

local M = {}

local default_whitespace_chars = { " ", "," }

-- When the cursor is placed on whitespace within a form then the node returned by
-- the treesitter `get_node_at_cursor` fn is the outer form and not a child within
-- the form.
--
-- For example: `(aaa| bbb)` - the cursor `|` is placed on a whitespace char and so
-- the `get_node_at_cursor` returns "list_lit".
--
-- Motion commands expect to move to the next adjacent node within the form regardless
-- of whether the cursor is currently on a node or not.
--
-- This function attempts to find the next adjacent node from the cursor if the cursor
-- is placed on whitespace.
local function get_next_node_from_cursor(lang, reversed)
  local current_node = ts.get_node_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor = { cursor[1] - 1, cursor[2] }

  local char_under_cursor = vim.api.nvim_buf_get_text(0,
    cursor[1], cursor[2],
    cursor[1], cursor[2] + 1,
    {}
  )
  local char_is_whitespace = common.included_in_table(
    lang.whitespace_chars or default_whitespace_chars,
    char_under_cursor[1]
  ) or char_under_cursor[1] == ""

  if not (lang.node_is_form(current_node) and char_is_whitespace) then
    return lang.get_node_root(current_node)
  end

  for i = 0, current_node:named_child_count() - 1 do
    local child = current_node:named_child(i)
    local range = { child:range() }

    local child_is_next
    if reversed then
      child_is_next = common.pos_out_of_bounds(cursor, { range[3], range[4] })
    else
      child_is_next = common.pos_out_of_bounds(range, cursor)
    end

    if child_is_next then
      return child
    end
  end
end

function M.move_to_next_element()
  local lang = langs.get_language_api()

  local current_node = get_next_node_from_cursor(lang, false)
  if not current_node then
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_node_end = { current_node:end_() }

  local next_pos
  if cursor_pos[2] + 1 < current_node_end[2] then
    next_pos = current_node_end
  else
    local next_sibling = traversal.get_next_sibling_ignoring_comments(current_node, {
      lang = lang,
    })
    if next_sibling then
      next_pos = { next_sibling:end_() }
    end
  end

  if not next_pos then
    return
  end

  vim.api.nvim_win_set_cursor(0, { next_pos[1] + 1, next_pos[2] - 1 })
end

function M.move_to_prev_element()
  local lang = langs.get_language_api()
  local current_node = get_next_node_from_cursor(lang, true)
  if not current_node then
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_node_start = { current_node:start() }

  local next_pos
  if cursor_pos[2] > current_node_start[2] then
    next_pos = current_node_start
  else
    local prev_sibling = traversal.get_prev_sibling_ignoring_comments(current_node, {
      lang = lang,
    })
    if prev_sibling then
      next_pos = { prev_sibling:start() }
    end
  end

  if not next_pos then
    return
  end

  vim.api.nvim_win_set_cursor(0, { next_pos[1] + 1, next_pos[2] })
end

return M
