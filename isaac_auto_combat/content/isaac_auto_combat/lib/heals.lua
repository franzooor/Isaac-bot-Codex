--- Healing sub-system.
-- Selects hearts (or coins for Keeper) mid-combat when health is low.

local Heals = {}

local sense = require("isaac_auto_combat.lib.sense")
local blackboard = require("isaac_auto_combat.lib.blackboard")

local function ensure_state(state)
  state.heals = state.heals or {
    target = nil,
    lastHP = nil,
    lastTrigger = -120,
  }
  state.memory = state.memory or {}
  state.memory.deferredPickups = state.memory.deferredPickups or {}
end

local function combined_hp(snapshot)
  if not snapshot then
    return 0
  end
  return (snapshot.redHearts or 0) + (snapshot.soulHearts or 0) + (snapshot.blackHearts or 0) * 2
end

local function heal_value_for_pickup(pickup, snapshot)
  if pickup.variant == PickupVariant.PICKUP_HEART then
    local subtype = pickup.subtype or pickup.SubType
    if subtype == HeartSubType.HEART_FULL or subtype == HeartSubType.HEART_DOUBLEPACK then
      return 2
    elseif subtype == HeartSubType.HEART_SOUL then
      return 2.5
    elseif subtype == HeartSubType.HEART_HALF_SOUL then
      return 1.25
    elseif subtype == HeartSubType.HEART_BLACK then
      return 2.5
    elseif subtype == HeartSubType.HEART_GOLDEN then
      return 3
    elseif subtype == HeartSubType.HEART_HALF then
      return 1
    elseif subtype == HeartSubType.HEART_BONE or subtype == HeartSubType.HEART_ROTTEN then
      return 1.5
    elseif subtype == HeartSubType.HEART_BLENDED then
      return 2.5
    elseif subtype == HeartSubType.HEART_ETERNAL then
      return 2
    end
  elseif snapshot and snapshot.playerType == PlayerType.PLAYER_KEEPER and pickup.variant == PickupVariant.PICKUP_COIN then
    return 1.5
  end
  return 0
end

local function score_pickup(pickup, snapshot, playerPos)
  local value = heal_value_for_pickup(pickup, snapshot)
  if value <= 0 then
    return -math.huge
  end
  local distance = (pickup.position - playerPos):Length()
  local score = value - (distance / 140)
  if pickup.wait and pickup.wait > 0 then
    score = score - 0.25
  end
  return score
end

local function find_best_heart(state, snapshot)
  local playerPos = snapshot and snapshot.position
  if not playerPos then
    return nil
  end

  local best = nil
  local bestScore = -math.huge
  local bestPickup = nil

  for _, pickup in ipairs(state.percepts.pickups or {}) do
    local score = score_pickup(pickup, snapshot, playerPos)
    if score > bestScore then
      if sense.has_los(playerPos, pickup.position, GridCollisionClass.COLLISION_PIT) then
        bestScore = score
        best = pickup
      else
        table.insert(state.memory.deferredPickups, pickup.id)
      end
    end
  end

  return best, bestScore
end

function Heals.init(state)
  ensure_state(state)
end

function Heals.update(state)
  ensure_state(state)
  local snapshot = state.percepts.player
  local currentHP = combined_hp(snapshot)
  if state.heals.lastHP and currentHP < state.heals.lastHP then
    blackboard.note_event(state, "took_damage")
    state.heals.lastTrigger = state.frame
  end
  state.heals.lastHP = currentHP

  local hpThreshold = (snapshot and snapshot.maxHearts or 6) * 0.75
  if snapshot and snapshot.playerType == PlayerType.PLAYER_KEEPER then
    hpThreshold = 2
  end

  local needHeal = currentHP <= hpThreshold or blackboard.ts(state, "took_damage") < 90
  if state.submode == "HEAL" and not needHeal then
    state.submode = nil
    state.heals.target = nil
    return
  end

  if not needHeal then
    state.heals.target = nil
    return
  end

  local best, score = find_best_heart(state, snapshot)
  if best and score > 0 then
    state.heals.target = {
      pickupId = best.id,
      position = best.position,
      score = score,
      setFrame = state.frame,
    }
    state.submode = "HEAL"
  elseif state.submode == "HEAL" then
    state.submode = nil
    state.heals.target = nil
  end
end

function Heals.current_target(state)
  ensure_state(state)
  return state.heals.target
end

function Heals.debug(state)
  ensure_state(state)
  local target = state.heals.target
  if not target then
    return { "heal: none" }
  end
  return { string.format("heal -> %d score=%.2f", target.pickupId or 0, target.score or 0) }
end

return Heals
