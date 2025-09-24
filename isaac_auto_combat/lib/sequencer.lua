--- Sequencer for ordered actions.
-- Runs small scripts that override player input for a few frames.

local Sequencer = {}

local function ensure_state(state)
  state.sequencer = state.sequencer or {
    active = nil,
    controls = {
      buttons = {},
      move = Vector(0, 0),
      shoot = Vector(0, 0),
    },
    holdTimers = {},
    waitFrames = 0,
  }
end

local function reset_controls(ctrl)
  ctrl.move = Vector(0, 0)
  ctrl.shoot = Vector(0, 0)
  for k, _ in pairs(ctrl.buttons) do
    ctrl.buttons[k] = { pressed = false, triggered = false, value = 0 }
  end
end

local function set_button(ctrl, action, pressed, triggered)
  ctrl.buttons[action] = ctrl.buttons[action] or { pressed = false, triggered = false, value = 0 }
  ctrl.buttons[action].pressed = pressed
  ctrl.buttons[action].triggered = triggered or false
  ctrl.buttons[action].value = pressed and 1 or 0
end

local function compute_direction(playerPos, targetPos)
  if not playerPos or not targetPos then
    return Vector(0, 0)
  end
  local diff = targetPos - playerPos
  if diff:Length() < 0.001 then
    return Vector(0, 0)
  end
  return diff:Resized(1)
end

local scripts = {}

scripts.THROW_BOMB_AT = function(state, args)
  local playerPos = state.percepts.player and state.percepts.player.position
  local targetPos = args and args.targetPos or playerPos
  return {
    { type = "press", action = ButtonAction.ACTION_DROP },
    { type = "wait", frames = 8 },
    { type = "face", vector = compute_direction(playerPos, targetPos), frames = 12 },
    { type = "release", action = ButtonAction.ACTION_DROP },
  }
end

local function start_script(state, name, args)
  local generator = scripts[name]
  if not generator then
    return false
  end
  local steps = generator(state, args)
  if not steps or #steps == 0 then
    return false
  end
  state.sequencer.active = {
    name = name,
    steps = steps,
    index = 1,
  }
  state.sequencer.waitFrames = 0
  reset_controls(state.sequencer.controls)
  return true
end

local function finish(state)
  state.sequencer.active = nil
  state.sequencer.waitFrames = 0
  reset_controls(state.sequencer.controls)
  state.intent.sequenceControls = nil
end

local function apply_controls(state)
  state.intent.sequenceControls = state.intent.sequenceControls or {
    buttons = {},
    move = Vector(0, 0),
    shoot = Vector(0, 0),
  }
  local ctrl = state.sequencer.controls
  state.intent.sequenceControls.buttons = {}
  for action, entry in pairs(ctrl.buttons) do
    state.intent.sequenceControls.buttons[action] = {
      pressed = entry.pressed,
      triggered = entry.triggered,
      value = entry.value,
    }
  end
  state.intent.sequenceControls.move = Vector(ctrl.move.X, ctrl.move.Y)
  state.intent.sequenceControls.shoot = Vector(ctrl.shoot.X, ctrl.shoot.Y)
end

local function advance_step(state, step)
  local ctrl = state.sequencer.controls
  if step.type == "press" then
    set_button(ctrl, step.action, true, true)
    state.sequencer.holdTimers[step.action] = math.max(state.sequencer.holdTimers[step.action] or 0, step.frames or 1)
  elseif step.type == "hold" then
    set_button(ctrl, step.action, true, false)
    state.sequencer.holdTimers[step.action] = (step.frames or 3)
  elseif step.type == "release" then
    set_button(ctrl, step.action, false, false)
    state.sequencer.holdTimers[step.action] = 0
  elseif step.type == "move" then
    ctrl.move = step.vector or Vector(0, 0)
    state.sequencer.moveTimer = step.frames or 1
  elseif step.type == "face" then
    ctrl.shoot = step.vector or Vector(0, 0)
    state.sequencer.shootTimer = step.frames or 1
  elseif step.type == "wait" then
    state.sequencer.waitFrames = step.frames or 1
  end
end

function Sequencer.init(state)
  ensure_state(state)
end

function Sequencer.update(state)
  ensure_state(state)
  if not state.intent then
    return
  end

  if not state.sequencer.active then
    state.intent.sequenceControls = nil
    return
  end

  local ctrl = state.sequencer.controls
  for _, entry in pairs(ctrl.buttons) do
    entry.triggered = false
  end
  for action, timer in pairs(state.sequencer.holdTimers) do
    if timer and timer > 0 then
      set_button(ctrl, action, true, false)
      state.sequencer.holdTimers[action] = timer - 1
    elseif timer == 0 then
      set_button(ctrl, action, false, false)
      state.sequencer.holdTimers[action] = nil
    end
  end

  if state.sequencer.moveTimer then
    if state.sequencer.moveTimer <= 0 then
      ctrl.move = Vector(0, 0)
      state.sequencer.moveTimer = nil
    else
      state.sequencer.moveTimer = state.sequencer.moveTimer - 1
    end
  end

  if state.sequencer.shootTimer then
    if state.sequencer.shootTimer <= 0 then
      ctrl.shoot = Vector(0, 0)
      state.sequencer.shootTimer = nil
    else
      state.sequencer.shootTimer = state.sequencer.shootTimer - 1
    end
  end

  if state.sequencer.waitFrames > 0 then
    state.sequencer.waitFrames = state.sequencer.waitFrames - 1
    apply_controls(state)
    return
  end

  local active = state.sequencer.active
  local step = active.steps[active.index]
  if step then
    advance_step(state, step)
    active.index = active.index + 1
    if active.index > #active.steps then
      finish(state)
    else
      apply_controls(state)
    end
  else
    finish(state)
  end
  if state.sequencer.active then
    apply_controls(state)
  end
end

function Sequencer.queue(state, name, args)
  ensure_state(state)
  if state.sequencer.active then
    return false
  end
  return start_script(state, name, args)
end

function Sequencer.is_running(state)
  ensure_state(state)
  return state.sequencer.active ~= nil
end

function Sequencer.interrupt(state)
  ensure_state(state)
  finish(state)
end

function Sequencer.debug(state)
  ensure_state(state)
  if not state.sequencer.active then
    return { "seq: idle" }
  end
  return { string.format("seq: %s step=%d", state.sequencer.active.name, state.sequencer.active.index or 0) }
end

return Sequencer
