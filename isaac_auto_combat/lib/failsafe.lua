--- Failsafe module.
-- Detects stuck states and attempts recovery moves.

local Failsafe = {}

local blackboard = require("isaac_auto_combat.lib.blackboard")

local rng = RNG()

local function ensure_state(state)
  state.failsafe = state.failsafe or {
    stuckFrames = 0,
    wiggleTimer = 0,
    disableTimer = 0,
    overlay = {},
  }
end

local function random_direction()
  local angle = rng:RandomFloat() * 360
  return Vector.FromAngle(angle)
end

function Failsafe.init(state)
  ensure_state(state)
end

function Failsafe.update(state)
  ensure_state(state)
  local overlay = {}

  if state.failsafe.disableTimer and state.failsafe.disableTimer > 0 then
    state.failsafe.disableTimer = state.failsafe.disableTimer - 1
    if state.failsafe.disableTimer == 0 then
      state.enabled = true
    end
    table.insert(overlay, string.format("cooldown %d", state.failsafe.disableTimer))
  end

  if not state.enabled then
    state.failsafe.overlay = overlay
    return
  end

  local motion = blackboard.motion_delta(state, 12)
  local playerExists = state.percepts.player and state.percepts.player.exists
  if not playerExists then
    state.failsafe.stuckFrames = 0
    state.failsafe.overlay = overlay
    return
  end

  if motion < 4 and (state.mode == "COMBAT" or state.mode == "TRANSIT") then
    state.failsafe.stuckFrames = state.failsafe.stuckFrames + 1
  else
    state.failsafe.stuckFrames = math.max(0, state.failsafe.stuckFrames - 2)
  end

  local sequencer = state.sequencer and state.sequencer.active

  if state.failsafe.stuckFrames > 60 and not sequencer then
    if state.failsafe.wiggleTimer <= 0 then
      state.failsafe.wiggleTimer = 20
      state.failsafe.wiggleDir = random_direction()
    end
  end

  if state.failsafe.wiggleTimer and state.failsafe.wiggleTimer > 0 and not sequencer then
    state.intent.move = (state.intent.move or Vector(0, 0)) + state.failsafe.wiggleDir
    state.failsafe.wiggleTimer = state.failsafe.wiggleTimer - 1
    table.insert(overlay, "wiggle")
  end

  if state.failsafe.stuckFrames > 180 then
    state.enabled = false
    state.failsafe.disableTimer = 90
    table.insert(overlay, "panic")
  end

  state.failsafe.overlay = overlay
end

function Failsafe.debug(state)
  ensure_state(state)
  return state.failsafe.overlay or {}
end

return Failsafe
