--- Blackboard state container for the auto combat mod.
-- Provides a single table shared across modules.
-- Exposes helpers for time stamps, rolling motion deltas, and intent resets.

local Blackboard = {}

local MOTION_BUFFER = 18

local function new_intent()
  return {
    move = Vector(0, 0),
    shoot = Vector(0, 0),
    fire = false,
    useActive = false,
    useBomb = false,
    sequenceControls = nil,
  }
end

local function ensure_tables(state)
  state.memory = state.memory or {}
  state.goals = state.goals or {}
  state.capabilities = state.capabilities or {}
  state.firepolicy = state.firepolicy or {}
  state.percepts = state.percepts or {}
  state.economy = state.economy or {}
  state.planning = state.planning or { route = {}, crumbs = {} }
  state.endgoal = state.endgoal or { name = nil, checklist = "" }
  state.timers = state.timers or {}
  state.motionHistory = state.motionHistory or {}
  state.telemetry = state.telemetry or { notes = {} }
end

function Blackboard.init()
  local state = {
    frame = 0,
    enabled = false,
    mode = "TRANSIT",
    submode = nil,
    intent = new_intent(),
    memory = {},
    goals = {},
    capabilities = {},
    firepolicy = {},
    percepts = {},
    economy = {},
    planning = { route = {}, crumbs = {} },
    endgoal = { name = nil, checklist = "" },
    timers = {},
    motionHistory = {},
    telemetry = { notes = {} },
  }

  return state
end

function Blackboard.reset_intent(state)
  if not state then
    return
  end

  state.intent = new_intent()
end

local function ensure_intent(state)
  if type(state.intent) ~= "table" then
    state.intent = new_intent()
  end

  state.intent.move = state.intent.move or Vector(0, 0)
  state.intent.shoot = state.intent.shoot or Vector(0, 0)
  state.intent.fire = state.intent.fire or false
  state.intent.useActive = state.intent.useActive or false
  state.intent.useBomb = state.intent.useBomb or false
  if state.intent.sequenceControls ~= nil and type(state.intent.sequenceControls) ~= "table" then
    state.intent.sequenceControls = nil
  end
end

function Blackboard.note_event(state, key)
  if not state or not key then
    return
  end

  state.timers = state.timers or {}
  state.timers[key] = state.frame or 0
end

function Blackboard.ts(state, key)
  if not state or not key then
    return math.huge
  end

  state.timers = state.timers or {}
  local at = state.timers[key]
  if not at then
    return math.huge
  end

  return (state.frame or 0) - at
end

local function update_motion_history(state, position)
  if not state then
    return
  end

  if not position then
    return
  end

  state.motionHistory = state.motionHistory or {}
  table.insert(state.motionHistory, { frame = state.frame or 0, position = position })
  while #state.motionHistory > MOTION_BUFFER do
    table.remove(state.motionHistory, 1)
  end
end

function Blackboard.motion_delta(state, frames)
  if not state or not state.motionHistory or #state.motionHistory == 0 then
    return 0
  end

  frames = frames or MOTION_BUFFER

  local newest = state.motionHistory[#state.motionHistory]
  local oldest = newest
  for i = #state.motionHistory, 1, -1 do
    local entry = state.motionHistory[i]
    if newest.frame - entry.frame >= frames then
      oldest = entry
      break
    end
    oldest = entry
  end

  local diff = newest.position - oldest.position
  return diff:Length()
end

function Blackboard.update(state, playerPosition)
  if state == nil then
    return
  end

  state.frame = (state.frame or 0) + 1

  ensure_intent(state)
  ensure_tables(state)

  if playerPosition then
    update_motion_history(state, playerPosition)
  end

  state.mode = state.mode or "TRANSIT"
end

function Blackboard.debug(state)
  if not state then
    return { "[blackboard] missing state" }
  end

  return {
    string.format("frame=%d", state.frame or -1),
    string.format("enabled=%s", tostring(state.enabled)),
    string.format("mode=%s", state.mode or "nil"),
    string.format("submode=%s", state.submode or "-"),
  }
end

return Blackboard
