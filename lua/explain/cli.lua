-- Runs `claude -p` and turns its stream-json output into answer text.

local config = require 'explain.config'

local M = {}

function M.has_claude()
  if vim.fn.executable(config.options.cmd) == 1 then
    return true
  end
  vim.notify(string.format('explain.nvim: `%s` is not on the PATH Neovim was started with', config.options.cmd), vim.log.levels.ERROR)
  return false
end

function M.model_args(mode)
  local args = { '--model', mode.model }
  if mode.effort then
    vim.list_extend(args, { '--effort', mode.effort })
  end
  return args
end

function M.build_command(mode)
  local cmd = vim.list_extend({ config.options.cmd, '-p' }, M.model_args(mode))
  vim.list_extend(cmd, {
    '--strict-mcp-config',
    '--disable-slash-commands',
    '--output-format',
    'stream-json',
    '--include-partial-messages',
    '--verbose',
  })
  if mode.lite then
    -- Empty values disable all tools and skip user/project settings (and with them CLAUDE.md)
    return vim.list_extend(cmd, { '--system-prompt', config.options.lite.system_prompt, '--tools', '', '--setting-sources', '' })
  end
  return vim.list_extend(cmd, { '--append-system-prompt', config.options.deep.append_system_prompt, '--tools', table.concat(config.options.deep.tools, ',') })
end

-- stdout arrives in arbitrary chunks, so this buffers until each JSON line is complete.
-- Returns a feed(data) function that calls on_event for every decoded line.
function M.new_parser(on_event)
  local pending = ''
  return function(data)
    pending = pending .. data
    for line in pending:gmatch '([^\n]*)\n' do
      local ok, ev = pcall(vim.json.decode, line)
      if ok and type(ev) == 'table' then
        on_event(ev)
      end
    end
    pending = pending:match '[^\n]*$'
  end
end

-- Applies one stream-json event to state.text and state.session_id.
-- See `claude -p --output-format stream-json --include-partial-messages` for the event shapes.
function M.apply_event(state, ev)
  if ev.type == 'system' and ev.session_id then
    state.session_id = ev.session_id
  elseif ev.type == 'result' and ev.is_error then
    state.text = state.text .. '\n\n**Error:** ' .. tostring(ev.result)
  elseif ev.type == 'result' and state.text == '' and type(ev.result) == 'string' then
    state.text = ev.result
  elseif ev.type == 'stream_event' then
    local e = ev.event
    if e.type == 'message_start' and state.text ~= '' then
      state.text = state.text .. '\n\n'
    elseif e.type == 'content_block_start' and e.content_block.type == 'tool_use' then
      state.text = state.text .. '`[' .. e.content_block.name .. ']` '
    elseif e.type == 'content_block_delta' and e.delta.type == 'text_delta' then
      state.text = state.text .. e.delta.text
    end
  end
end

-- Streams the answer for prompt into state, calling on_update after every chunk and once more when
-- done. Returns the vim.SystemObj, so the request can be killed.
function M.run(state, prompt, on_update)
  local feed = M.new_parser(function(ev)
    M.apply_event(state, ev)
  end)
  return vim.system(M.build_command(state.mode), {
    cwd = state.root,
    stdin = prompt,
    text = true,
    stdout = function(_, data)
      if data then
        vim.schedule(function()
          feed(data)
          on_update()
        end)
      end
    end,
  }, function(res)
    vim.schedule(function()
      state.done = true
      if res.code ~= 0 and state.text == '' then
        state.text = '**claude exited with status ' .. res.code .. '**\n\n' .. (res.stderr or '')
      end
      on_update()
    end)
  end)
end

return M
