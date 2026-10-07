local cli = require 'explain.cli'
local config = require 'explain.config'
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function has_pair(cmd, flag, value)
  for i = 1, #cmd - 1 do
    if cmd[i] == flag and cmd[i + 1] == value then
      return true
    end
  end
  return false
end

T['build_command()'] = MiniTest.new_set()

-- These flags are what keep a lite call at ~0.5k input tokens instead of ~13k
T['build_command()']['lite mode replaces the prompt and disables tools and settings'] = function()
  local cmd = cli.build_command(config.mode 'quick')
  eq(has_pair(cmd, '--system-prompt', config.options.lite.system_prompt), true)
  eq(has_pair(cmd, '--tools', ''), true)
  eq(has_pair(cmd, '--setting-sources', ''), true)
  eq(vim.tbl_contains(cmd, '--append-system-prompt'), false)
end

T['build_command()']['deep mode keeps the default prompt and allows read-only tools'] = function()
  local cmd = cli.build_command(config.mode 'deep')
  eq(has_pair(cmd, '--tools', 'Read,Grep,Glob'), true)
  eq(vim.tbl_contains(cmd, '--system-prompt'), false)
  eq(vim.tbl_contains(cmd, '--setting-sources'), false)
end

T['new_parser()'] = MiniTest.new_set()

T['new_parser()']['joins JSON lines split across chunks'] = function()
  local events = {}
  local feed = cli.new_parser(function(ev)
    table.insert(events, ev)
  end)
  feed '{"type":"sys'
  eq(#events, 0)
  feed 'tem","session_id":"abc"}\n{"type":"res'
  eq(events, { { type = 'system', session_id = 'abc' } })
  feed 'ult"}\n'
  eq(#events, 2)
  eq(events[2].type, 'result')
end

T['new_parser()']['skips lines that are not JSON'] = function()
  local events = {}
  local feed = cli.new_parser(function(ev)
    table.insert(events, ev)
  end)
  feed 'warning: something\n{"type":"result"}\n'
  eq(events, { { type = 'result' } })
end

T['apply_event()'] = MiniTest.new_set()

local function delta(text)
  return { type = 'stream_event', event = { type = 'content_block_delta', delta = { type = 'text_delta', text = text } } }
end

T['apply_event()']['builds the answer from text deltas'] = function()
  local state = { text = '' }
  cli.apply_event(state, { type = 'system', subtype = 'init', session_id = 's1' })
  cli.apply_event(state, delta 'C has no ')
  cli.apply_event(state, delta '** operator.')
  eq(state, { text = 'C has no ** operator.', session_id = 's1' })
end

T['apply_event()']['separates messages and marks tool use'] = function()
  local state = { text = 'Let me check.' }
  cli.apply_event(state, { type = 'stream_event', event = { type = 'message_start' } })
  cli.apply_event(state, { type = 'stream_event', event = { type = 'content_block_start', content_block = { type = 'tool_use', name = 'Read' } } })
  cli.apply_event(state, delta 'Found it.')
  eq(state.text, 'Let me check.\n\n`[Read]` Found it.')
end

T['apply_event()']['falls back to the final result when nothing streamed'] = function()
  local state = { text = '' }
  cli.apply_event(state, { type = 'result', is_error = false, result = 'The answer.' })
  eq(state.text, 'The answer.')
end

T['apply_event()']['does not repeat a streamed answer from the result'] = function()
  local state = { text = 'Streamed.' }
  cli.apply_event(state, { type = 'result', is_error = false, result = 'Streamed.' })
  eq(state.text, 'Streamed.')
end

T['apply_event()']['shows errors'] = function()
  local state = { text = '' }
  cli.apply_event(state, { type = 'result', is_error = true, result = 'Rate limited' })
  eq(state.text, '\n\n**Error:** Rate limited')
end

return T
