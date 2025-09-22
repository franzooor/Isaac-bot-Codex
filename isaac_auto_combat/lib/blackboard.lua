--- Blackboard state container for the auto combat mod.
-- Provides a single table shared across modules.
-- Exposes init/update/debug functions as required by project conventions.

local Blackboard = {}

local function new_intent()
  return {
    move = Vector(0, 0),
    shoot = Vector(0, 0),
    fire = false,
    useActive = false,
    useBomb = false,
    dropCard = false,
    usePill = false,
    sequenceControls = {},
  }
end

function Blackboard.init()
  local state = {
    frame = 0,
    enabled = false,
    mode = "idle",
    intent = new_intent(),
    memory = {},
    goals = {},
    capabilities = {},
    firepolicy = {},
    percepts = {},
    config = {},
    timers = {},
    telemetry = {
      notes = {},
    },
  }

  return state
end

function Blackboard.update(state)
  if state == nil then
    return
  end

  state.frame = (state.frame or 0) + 1

  if type(state.intent) ~= "table" then
    state.intent = new_intent()
  end

  state.intent.move = state.intent.move or Vector(0, 0)
  state.intent.shoot = state.intent.shoot or Vector(0, 0)
  state.intent.sequenceControls = state.intent.sequenceControls or {}
  state.mode = state.mode or "idle"
  state.memory = state.memory or {}
  state.goals = state.goals or {}
  state.capabilities = state.capabilities or {}
  state.firepolicy = state.firepolicy or {}
  state.percepts = state.percepts or {}
  state.timers = state.timers or {}
  state.telemetry = state.telemetry or { notes = {} }
end

function Blackboard.debug(state)
  if not state then
    return { "[blackboard] missing state" }
  end

  return {
    string.format("frame=%d", state.frame or -1),
    string.format("enabled=%s", tostring(state.enabled)),
    string.format("mode=%s", state.mode or "nil"),
  }
end

return Blackboard
