--- Core orchestrator for the auto combat bot.
-- Ties together sensing, planning, and decision modules each frame.

local Controller = {}

local blackboard = require("isaac_auto_combat.lib.blackboard")
local sense = require("isaac_auto_combat.lib.sense")
local firestyle = require("isaac_auto_combat.lib.firestyle")
local bombs = require("isaac_auto_combat.lib.bombs")
local heals = require("isaac_auto_combat.lib.heals")
local loot = require("isaac_auto_combat.lib.loot")
local map = require("isaac_auto_combat.lib.map")
local roomminmax = require("isaac_auto_combat.lib.roomminmax")
local economy = require("isaac_auto_combat.lib.economy")
local plan = require("isaac_auto_combat.lib.plan")
local bossbook = require("isaac_auto_combat.lib.bossbook")
local sequencer = require("isaac_auto_combat.lib.sequencer")
local failsafe = require("isaac_auto_combat.lib.failsafe")
local item_scoring = require("isaac_auto_combat.lib.item_scoring")
local endgoal = require("isaac_auto_combat.lib.endgoal")
local decide = require("isaac_auto_combat.lib.decide")

local function ensure_state(state)
  state.controller = state.controller or {
    lastPlayerPtr = nil,
  }
end

function Controller.init(state)
  ensure_state(state)
  sense.init(state)
  firestyle.init(state)
  bombs.init(state)
  heals.init(state)
  loot.init(state)
  map.init(state)
  roomminmax.init(state)
  economy.init(state)
  plan.init(state)
  bossbook.init(state)
  sequencer.init(state)
  failsafe.init(state)
  item_scoring.init(state)
  endgoal.init(state)
end

function Controller.reset(state)
  ensure_state(state)
  blackboard.reset_intent(state)
  plan.flag_for_replan(state, "reset")
  state.submode = nil
end

local function update_modules(state, player)
  sense.update(state, player)
  firestyle.update(state, player)
  bombs.update(state)
  economy.update(state, player)
  endgoal.update(state, player)
  map.update(state)
  heals.update(state)
  loot.update(state)
  roomminmax.update(state)
  plan.update(state)
  bossbook.update(state)
  item_scoring.update(state, player)
end

function Controller.update(state, player)
  ensure_state(state)
  update_modules(state, player)
  decide.update(state, player)
  sequencer.update(state)
  failsafe.update(state)
end

function Controller.debug(state)
  ensure_state(state)
  local sections = {}
  for _, module in ipairs({
    blackboard,
    sense,
    firestyle,
    bombs,
    heals,
    loot,
    map,
    plan,
    bossbook,
    sequencer,
    failsafe,
    item_scoring,
    endgoal,
  }) do
    if module.debug then
      local lines = module.debug(state)
      for _, line in ipairs(lines or {}) do
        table.insert(sections, line)
      end
    end
  end
  return sections
end

return Controller
