--- Loot selection module.
-- Scores room pickups when the room is clear and selects a target.

local Loot = {}

local sense = require("isaac_auto_combat.lib.sense")

local priorities = {
  [PickupVariant.PICKUP_HEART] = 6,
  [PickupVariant.PICKUP_LIL_BATTERY] = 5,
  [PickupVariant.PICKUP_KEY] = 4,
  [PickupVariant.PICKUP_BOMB] = 3,
  [PickupVariant.PICKUP_COIN] = 2,
  [PickupVariant.PICKUP_PILL] = 1,
  [PickupVariant.PICKUP_TAROTCARD] = 1,
  [PickupVariant.PICKUP_COLLECTIBLE] = 3,
}

local function ensure_state(state)
  state.loot = state.loot or {
    target = nil,
  }
  state.memory = state.memory or {}
  state.memory.deferredPickups = state.memory.deferredPickups or {}
end

local function base_value(pickup)
  return priorities[pickup.variant] or 0
end

local function score_pickup(pickup, playerPos)
  local value = base_value(pickup)
  if value <= 0 then
    return -math.huge
  end
  local distance = (pickup.position - playerPos):Length()
  return value - (distance / 160)
end

function Loot.init(state)
  ensure_state(state)
end

function Loot.update(state)
  ensure_state(state)
  local room = Game():GetRoom()
  if not room or not room:IsClear() then
    state.loot.target = nil
    return
  end

  if state.submode == "HEAL" then
    return
  end

  local snapshot = state.percepts.player
  local playerPos = snapshot and snapshot.position
  if not playerPos then
    return
  end

  local best = nil
  local bestScore = -math.huge
  for _, pickup in ipairs(state.percepts.pickups or {}) do
    local priority = base_value(pickup)
    if priority > 0 then
      local score = score_pickup(pickup, playerPos)
      if score > bestScore then
        if sense.has_los(playerPos, pickup.position, GridCollisionClass.COLLISION_PIT) then
          bestScore = score
          best = pickup
        else
          table.insert(state.memory.deferredPickups, pickup.id)
        end
      end
    end
  end

  if best then
    state.loot.target = {
      pickupId = best.id,
      position = best.position,
      variant = best.variant,
      priority = priorities[best.variant] or 0,
      score = bestScore,
    }
    if state.mode ~= "COMBAT" then
      state.mode = "LOOT"
    end
  else
    if state.mode == "LOOT" then
      state.mode = "TRANSIT"
    end
    state.loot.target = nil
  end
end

function Loot.current_target(state)
  ensure_state(state)
  return state.loot.target
end

function Loot.debug(state)
  ensure_state(state)
  if not state.loot.target then
    return { "loot: none" }
  end
  return { string.format("loot -> %d score=%.2f", state.loot.target.pickupId or 0, state.loot.target.score or 0) }
end

return Loot
