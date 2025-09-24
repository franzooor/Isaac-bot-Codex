local AutoCombatMod = RegisterMod("Auto Combat Handler", 1)

local game = Game()

local blackboard = require("isaac_auto_combat.lib.blackboard")
local debugui = require("isaac_auto_combat.lib.debugui")
local act = require("isaac_auto_combat.lib.act")
local controller = require("isaac_auto_combat.lib.controller")

local defaults = require("isaac_auto_combat.config.defaults")
local userPrefs = require("isaac_auto_combat.config.user_prefs")

local function toggle_enabled(state)
  if not state then
    return false
  end

  if state.lastToggleFrame == state.frame then
    return false
  end

  state.enabled = not state.enabled
  state.lastToggleFrame = state.frame

  if state.enabled then
    state.mode = "idle"
  else
    state.mode = "manual"
    blackboard.reset_intent(state)
  end

  controller.reset(state)

  return true
end

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

blackboard.reset_intent(state)

blackboard.update(state)
debugui.init(state)
act.init(state)
controller.init(state)
controller.reset(state)

local function on_post_update()
  if game:IsPaused() then
    return
  end

  local player = Isaac.GetPlayer(0)
  local playerPos = player and player.Position or nil
  blackboard.update(state, playerPos)

  if player and state.config.toggleKey and Input and Input.IsButtonTriggered then
    local controllerIndex = player.ControllerIndex or 0
    if controllerIndex <= 0 and Input.IsButtonTriggered(state.config.toggleKey, controllerIndex) then
      toggle_enabled(state)
    end
  end

  if not state.enabled then
    state.mode = "manual"
  elseif state.mode == "manual" then
    state.mode = "idle"
  end

  controller.update(state, player)
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
  blackboard.reset_intent(state)
  controller.reset(state)
end

local function on_input_action(_, entity, hook, action)
  local player = entity and entity:ToPlayer()
  if player then
    local controllerIndex = player.ControllerIndex or 0
    if controllerIndex > 0 then
      return nil
    end
  end

  if state.config.toggleAction ~= nil then
    if player and hook == InputHook.IS_ACTION_PRESSED and action == state.config.toggleAction and state.enabled then
      return false
    end

    if player and hook == InputHook.GET_ACTION_VALUE and action == state.config.toggleAction and state.enabled then
      return 0
    end

    if player and hook == InputHook.IS_ACTION_TRIGGERED and action == state.config.toggleAction then
      local toggled = toggle_enabled(state)

      if toggled or state.enabled then
        return false
      end
    end
  end

  local result = act.on_input(state, player, hook, action)
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
