--- Minimal overlay renderer for the auto combat mod.
-- Renders baseline telemetry showing enable state, mode, and frame count.

local DebugUI = {}

local baseX = 30
local baseY = 40
local lineHeight = 11

local function ensure_state(state)
  state.debugui = state.debugui or {
    lines = {},
    lastFrame = 0,
  }
end

local function append_lines(lines, label, entries)
  if entries and #entries > 0 then
    table.insert(lines, label .. table.concat(entries, " | "))
  end
end

function DebugUI.init(state)
  ensure_state(state)
end

function DebugUI.update(state)
  ensure_state(state)
  if state.config and state.config.overlay and state.config.overlay.enabled == false then
    state.debugui.lines = {}
    return
  end

  local lines = {}
  table.insert(lines, string.format("[AutoCombat] %s", state.enabled and "ENABLED" or "DISABLED"))

  local targetLine = string.format("Mode:%s", state.mode or "idle")
  if state.submode then
    targetLine = targetLine .. string.format(" (%s)", state.submode)
  end
  local targetId = state.decide and state.decide.target or nil
  if targetId then
    targetLine = targetLine .. string.format(" tgt:%s", tostring(targetId))
  end
  if state.decide and state.decide.topMove then
    targetLine = targetLine .. string.format(" mv:%s %.2f", state.decide.topMove.name or "idle", state.decide.topMove.score or 0)
  end
  table.insert(lines, targetLine)

  local capabilityLines = {}
  if state.capabilities then
    if state.capabilities.charge then table.insert(capabilityLines, "charge") end
    if state.capabilities.knife then table.insert(capabilityLines, "knife") end
    if state.capabilities.ludo then table.insert(capabilityLines, "ludo") end
    if state.capabilities.fetus or state.capabilities.epicFetus then table.insert(capabilityLines, "fetus") end
    if state.capabilities.explosiveRadius and state.capabilities.explosiveRadius > 0 then
      table.insert(capabilityLines, string.format("expl%.0f", state.capabilities.explosiveRadius))
    end
    if state.firepolicy and state.firepolicy.suppress_reason then
      table.insert(capabilityLines, "SUPPRESS:" .. state.firepolicy.suppress_reason)
    end
  end
  append_lines(lines, "Cap:", capabilityLines)

  if state.bombs and state.bombs.overlay then
    for _, text in ipairs(state.bombs.overlay) do
      table.insert(lines, "Bomb:" .. text)
    end
  end

  local activeGoal = state.planning and state.planning.activeGoal or nil
  if activeGoal then
    table.insert(lines, string.format("Goal:%s %.2f", activeGoal.name or "?", activeGoal.score or 0))
  end
  if state.planning and state.planning.crumbs and #state.planning.crumbs > 0 then
    table.insert(lines, "Route:" .. table.concat(state.planning.crumbs, " > "))
  end

  if state.economy and state.economy.reserves then
    local res = state.economy.reserves
    table.insert(lines, string.format("Eco:%s B%d K%d C%d H%d", state.economy.mode or "?", res.bombs or 0, res.keys or 0, res.coins or 0, res.hearts or 0))
    if state.economy.lastSpend and state.economy.lastSpend ~= "" then
      table.insert(lines, "Spend:" .. state.economy.lastSpend)
    end
  end

  if state.endgoal and state.endgoal.name then
    table.insert(lines, string.format("End:%s", state.endgoal.name))
    if state.endgoal.checklist and state.endgoal.checklist ~= "" then
      table.insert(lines, "Checklist:" .. state.endgoal.checklist)
    end
  end

  if state.firestyle and state.firestyle.overlay then
    for _, text in ipairs(state.firestyle.overlay) do
      table.insert(lines, "Fire:" .. text)
    end
  end

  if state.item_scoring and state.item_scoring.overlay then
    for _, text in ipairs(state.item_scoring.overlay) do
      table.insert(lines, "Item:" .. text)
    end
  end

  if state.failsafe and state.failsafe.overlay then
    for _, text in ipairs(state.failsafe.overlay) do
      table.insert(lines, "Failsafe:" .. text)
    end
  end

  state.debugui.lines = lines
  state.debugui.lastFrame = state.frame
end

function DebugUI.debug(state)
  ensure_state(state)
  return state.debugui.lines or {}
end

function DebugUI.render(state)
  ensure_state(state)
  if state.config and state.config.overlay and state.config.overlay.enabled == false then
    return
  end

  local lines = state.debugui.lines or {}
  for i, line in ipairs(lines) do
    Isaac.RenderText(line, baseX, baseY + (i - 1) * lineHeight, 1, 1, 1, 1)
  end
end

return DebugUI
