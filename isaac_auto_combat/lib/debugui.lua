--- Minimal overlay renderer for the auto combat mod.
-- Renders baseline telemetry showing enable state, mode, and frame count.

local DebugUI = {}

local baseX = 30
local baseY = 40
local lineHeight = 12

local function safe_count(list)
  if type(list) ~= "table" then
    return 0
  end

  return #list
end

local function format_vector(vec)
  if type(vec) ~= "table" then
    return "(0,0)"
  end

  return string.format("(%.2f, %.2f)", vec.x or vec.X or 0, vec.y or vec.Y or 0)
end

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

  local percepts = state.percepts or {}
  local player = percepts.player or {}
  local hearts = player.hearts or {}
  local entities = percepts.entities and percepts.entities.summary or {}
  local grid = percepts.grid or {}
  local hazards = grid.hazards or {}
  local room = percepts.room or {}
  local floor = percepts.floor or {}

  if player.name ~= nil then
    table.insert(lines, string.format(
      "HP R%.1f/%.1f S%.1f B%d G%d E%d",
      hearts.red or 0,
      hearts.max or 0,
      hearts.soul or 0,
      hearts.bone or 0,
      hearts.golden or 0,
      hearts.eternal or 0
    ))
    table.insert(lines, string.format(
      "Stats DMG%.2f DPS%.1f TPS%.2f SPD%.2f RNG%.1f LCK%.2f",
      player.damage or 0,
      player.dps or 0,
      player.tearsPerSecond or 0,
      player.speed or 0,
      player.range or 0,
      player.luck or 0
    ))
    table.insert(lines, string.format(
      "Flags Tear0x%X Bomb0x%X Weapon%d Dir%d",
      player.tearFlags or 0,
      player.bombFlags or 0,
      player.weaponType or 0,
      player.fireDirection or -1
    ))
    table.insert(lines, string.format(
      "Input move%s shoot%s",
      format_vector(player.moveInput),
      format_vector(player.shootInput)
    ))
  else
    table.insert(lines, "Player: N/A")
  end

  table.insert(lines, string.format(
    "Entities E%d(B%d/C%d) Proj%d Pick%d Bomb%d Fam%d Other%d",
    entities.enemyCount or 0,
    entities.bossCount or 0,
    entities.championCount or 0,
    entities.projectileCount or 0,
    entities.pickupCount or 0,
    entities.bombCount or 0,
    entities.familiarCount or 0,
    entities.otherCount or 0
  ))

  table.insert(lines, string.format(
    "Hazards spikes%d pits%d fires%d doors%d",
    safe_count(hazards.spikes),
    safe_count(hazards.pits),
    safe_count(hazards.fires),
    safe_count(grid.doors)
  ))

  table.insert(lines, string.format(
    "Room type%d variant%d clear=%s enemies=%d",
    room.type or -1,
    room.variant or -1,
    tostring(room.isClear),
    room.enemyKillCount or 0
  ))

  table.insert(lines, string.format(
    "Floor stage%d abs%d type%d curse0x%X rooms %d/%d",
    floor.stage or -1,
    floor.absoluteStage or -1,
    floor.stageType or -1,
    floor.curseMask or 0,
    floor.roomsCleared or 0,
    floor.totalRooms or 0
  ))

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
