--- Minimal overlay renderer for the auto combat mod.
-- Renders baseline telemetry showing enable state, mode, and frame count.

local DebugUI = {}

local baseX = 30
local baseY = 40
local lineHeight = 12

function DebugUI.init(state)
  state.debugui = state.debugui or {
    lines = {},
    lastFrame = 0,
  }
end

function DebugUI.update(state)
  if not state or not state.debugui then
    return
  end

  if state.config and state.config.overlay and state.config.overlay.enabled == false then
    state.debugui.lines = {}
    return
  end

  local lines = {}
  table.insert(lines, string.format("[AutoCombat] %s", state.enabled and "ENABLED" or "DISABLED"))
  table.insert(lines, string.format("Mode: %s", state.mode or "idle"))
  table.insert(lines, string.format("Frame: %d", state.frame or 0))

  state.debugui.lines = lines
  state.debugui.lastFrame = state.frame
end

function DebugUI.debug(state)
  if not state or not state.debugui then
    return { "debugui inactive" }
  end

  return state.debugui.lines or {}
end

function DebugUI.render(state)
  if not state or not state.debugui then
    return
  end

  if state.config and state.config.overlay and state.config.overlay.enabled == false then
    return
  end

  local lines = state.debugui.lines or {}
  for i, line in ipairs(lines) do
    Isaac.RenderText(line, baseX, baseY + (i - 1) * lineHeight, 1, 1, 1, 1)
  end
end

return DebugUI
