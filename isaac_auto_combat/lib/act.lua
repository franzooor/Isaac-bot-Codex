--- Action output module.
-- Translates the current intent on the shared state into concrete input values
-- returned through the MC_INPUT_ACTION hook.

local Act = {}

local axisThreshold = 0.15

local actionMap = {
  move = {
    { ButtonAction.ACTION_LEFT,  "x", -1 },
    { ButtonAction.ACTION_RIGHT, "x",  1 },
    { ButtonAction.ACTION_UP,    "y", -1 },
    { ButtonAction.ACTION_DOWN,  "y",  1 },
  },
  shoot = {
    { ButtonAction.ACTION_SHOOTLEFT,  "x", -1 },
    { ButtonAction.ACTION_SHOOTRIGHT, "x",  1 },
    { ButtonAction.ACTION_SHOOTUP,    "y", -1 },
    { ButtonAction.ACTION_SHOOTDOWN,  "y",  1 },
  },
}

local function resetOutputs(container)
  container.pressed = {}
  container.triggered = {}
  container.values = {}
end

local function encodeDirectionalIntent(outputs, vector, map)
  if not vector or vector.X == nil or vector.Y == nil then
    for _, entry in ipairs(map) do
      outputs.pressed[entry[1]] = false
      outputs.values[entry[1]] = 0
    end
    return
  end

  for _, entry in ipairs(map) do
    local action = entry[1]
    local axis = entry[2]
    local dir = entry[3]
    local component = axis == "x" and vector.X or vector.Y
    local pressed = false
    local value = 0

    if dir < 0 then
      pressed = component <= -axisThreshold
      value = pressed and math.min(1, math.abs(component)) or 0
    else
      pressed = component >= axisThreshold
      value = pressed and math.min(1, math.abs(component)) or 0
    end

    outputs.pressed[action] = pressed
    outputs.values[action] = value
  end
end

function Act.init(state)
  state.act = {
    outputs = {
      pressed = {},
      triggered = {},
      values = {},
    },
    lastIntentFrame = -1,
  }
end

local function apply_sequence_controls(outputs, sequence)
  if not sequence or not sequence.buttons then
    return
  end

  for action, entry in pairs(sequence.buttons) do
    outputs.pressed[action] = entry.pressed or false
    outputs.triggered[action] = entry.triggered or false
    outputs.values[action] = entry.value or (entry.pressed and 1 or 0)
  end
end

function Act.update(state)
  if not state or not state.act then
    return
  end

  local outputs = state.act.outputs
  resetOutputs(outputs)

  if not state.enabled then
    return
  end

  local intent = state.intent or {}
  local sequence = intent.sequenceControls

  local moveVector = sequence and sequence.move or intent.move
  encodeDirectionalIntent(outputs, moveVector, actionMap.move)

  local shootVector = sequence and sequence.shoot or intent.shoot
  local wantsFire = intent.fire == nil and false or intent.fire
  if not wantsFire and not sequence then
    shootVector = Vector(0, 0)
  end
  encodeDirectionalIntent(outputs, shootVector, actionMap.shoot)

  outputs.pressed[ButtonAction.ACTION_SHOOTLEFT] = outputs.pressed[ButtonAction.ACTION_SHOOTLEFT] or false
  outputs.pressed[ButtonAction.ACTION_SHOOTRIGHT] = outputs.pressed[ButtonAction.ACTION_SHOOTRIGHT] or false
  outputs.pressed[ButtonAction.ACTION_SHOOTUP] = outputs.pressed[ButtonAction.ACTION_SHOOTUP] or false
  outputs.pressed[ButtonAction.ACTION_SHOOTDOWN] = outputs.pressed[ButtonAction.ACTION_SHOOTDOWN] or false

  if intent.useActive then
    outputs.triggered[ButtonAction.ACTION_ITEM] = true
    outputs.pressed[ButtonAction.ACTION_ITEM] = true
  else
    outputs.triggered[ButtonAction.ACTION_ITEM] = false
    outputs.pressed[ButtonAction.ACTION_ITEM] = false
  end
  outputs.values[ButtonAction.ACTION_ITEM] = outputs.pressed[ButtonAction.ACTION_ITEM] and 1 or 0

  if intent.useBomb then
    outputs.triggered[ButtonAction.ACTION_BOMB] = true
    outputs.pressed[ButtonAction.ACTION_BOMB] = true
  else
    outputs.triggered[ButtonAction.ACTION_BOMB] = false
    outputs.pressed[ButtonAction.ACTION_BOMB] = false
  end
  outputs.values[ButtonAction.ACTION_BOMB] = outputs.pressed[ButtonAction.ACTION_BOMB] and 1 or 0

  if intent.dropCard then
    outputs.triggered[ButtonAction.ACTION_DROP] = true
    outputs.pressed[ButtonAction.ACTION_DROP] = true
  else
    outputs.triggered[ButtonAction.ACTION_DROP] = false
    outputs.pressed[ButtonAction.ACTION_DROP] = false
  end
  outputs.values[ButtonAction.ACTION_DROP] = outputs.pressed[ButtonAction.ACTION_DROP] and 1 or 0

  if intent.usePill then
    outputs.triggered[ButtonAction.ACTION_PILLCARD] = true
    outputs.pressed[ButtonAction.ACTION_PILLCARD] = true
  else
    outputs.triggered[ButtonAction.ACTION_PILLCARD] = false
    outputs.pressed[ButtonAction.ACTION_PILLCARD] = false
  end
  outputs.values[ButtonAction.ACTION_PILLCARD] = outputs.pressed[ButtonAction.ACTION_PILLCARD] and 1 or 0

  apply_sequence_controls(outputs, sequence)

  state.act.lastIntentFrame = state.frame
end

local function lookupOutputTable(container, action, default)
  if container[action] == nil then
    return default
  end
  return container[action]
end

function Act.on_input(state, player, hook, action)
  if not state or not state.act then
    return nil
  end

  if not state.enabled then
    return nil
  end

  if not player or not player:ToPlayer() then
    return nil
  end

  local outputs = state.act.outputs

  if hook == InputHook.IS_ACTION_PRESSED then
    return lookupOutputTable(outputs.pressed, action, nil)
  elseif hook == InputHook.IS_ACTION_TRIGGERED then
    return lookupOutputTable(outputs.triggered, action, nil)
  elseif hook == InputHook.GET_ACTION_VALUE then
    return lookupOutputTable(outputs.values, action, nil)
  end

  return nil
end

function Act.debug(state)
  if not state or not state.act then
    return { "act offline" }
  end

  return {
    string.format("intentFrame=%s", tostring(state.act.lastIntentFrame)),
  }
end

return Act
