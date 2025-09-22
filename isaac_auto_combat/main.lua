local AutoCombatMod = RegisterMod("Auto Combat Handler", 1)

local game = Game()

local blackboard = require("isaac_auto_combat.lib.blackboard")
local debugui = require("isaac_auto_combat.lib.debugui")
local act = require("isaac_auto_combat.lib.act")

local defaults = require("isaac_auto_combat.config.defaults")
local userPrefs = require("isaac_auto_combat.config.user_prefs")

local function deep_copy(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end

  local result = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      result[k] = deep_copy(v)
    else
      result[k] = v
    end
  end
  return result
end

local function merge_tables(base, overrides)
  local merged = deep_copy(base)
  for k, v in pairs(overrides) do
    if type(v) == "table" and type(merged[k]) == "table" then
      merged[k] = merge_tables(merged[k], v)
    else
      merged[k] = deep_copy(v)
    end
  end
  return merged
end

local state = blackboard.init()
state.config = merge_tables(defaults, userPrefs)
state.lastToggleFrame = -120
state.primaryControllerIndex = nil

local function reset_intent()
  state.intent = {
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

reset_intent()

blackboard.update(state)
debugui.init(state)
debugui.update(state)
act.init(state)

local function on_post_update()
  if game:IsPaused() then
    return
  end

  local player = game:GetPlayer(0)
  if player then
    state.primaryControllerIndex = player.ControllerIndex or 0
  end

  blackboard.update(state)

  if not state.enabled then
    state.mode = "manual"
  elseif state.mode == "manual" then
    state.mode = "idle"
  end

  act.update(state)
  debugui.update(state)
end

local function on_post_render()
  debugui.render(state)
end

local function on_post_new_room()
  if state.enabled then
    state.mode = "idle"
  else
    state.mode = "manual"
  end
  reset_intent()
end

local function should_handle_entity(entity)
  if entity == nil then
    return true
  end

  local player = entity:ToPlayer()
  if not player then
    return false
  end

  local controllerIndex = player.ControllerIndex or 0
  if state.primaryControllerIndex ~= nil and controllerIndex ~= state.primaryControllerIndex then
    return false
  end

  return true
end

local function suppress_action(hook)
  if hook == InputHook.GET_ACTION_VALUE then
    return 0
  end

  return false
end

local function on_input_action(entity, hook, action)
  if not should_handle_entity(entity) then
    return nil
  end

  if action == state.config.toggleAction then
    if hook == InputHook.IS_ACTION_TRIGGERED and state.lastToggleFrame ~= state.frame then
      state.enabled = not state.enabled
      state.lastToggleFrame = state.frame
      reset_intent()
      if state.enabled then
        state.mode = "idle"
      else
        state.mode = "manual"
      end
      act.update(state)
      debugui.update(state)
    end

    return suppress_action(hook)
  end

  local result = act.on_input(state, hook, action)
  if result ~= nil then
    return result
  end

  return nil
end

AutoCombatMod:AddCallback(ModCallbacks.MC_POST_UPDATE, on_post_update)
AutoCombatMod:AddCallback(ModCallbacks.MC_POST_RENDER, on_post_render)
AutoCombatMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, on_input_action)
AutoCombatMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, on_post_new_room)

return AutoCombatMod
