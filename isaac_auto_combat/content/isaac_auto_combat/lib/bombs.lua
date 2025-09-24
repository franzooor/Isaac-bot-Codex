--- Bomb intelligence module.
-- Tracks bombs, predicts blast radii, and recommends avoidance fields.

local Bombs = {}

local function ensure_state(state)
  state.bombs = state.bombs or {
    tracked = {},
    overlay = {},
    avoidance = {},
    lastDetonateFrame = -120,
  }
end

local function clear_array(arr)
  for i = #arr, 1, -1 do
    arr[i] = nil
  end
  return arr
end

local function compute_radius(bombEntry, playerSnapshot)
  local base = 90
  if bombEntry.radiusMultiplier and bombEntry.radiusMultiplier > 0 then
    base = base * bombEntry.radiusMultiplier
  end

  if playerSnapshot and playerSnapshot.bombs then
    if playerSnapshot.bombs.mrMega then
      base = base * 1.8
    end
    if playerSnapshot.bombs.bomberBoy then
      base = base * 1.1
    end
  end

  if bombEntry.variant == BombVariant.BOMB_GIGA then
    base = base * 2.4
  elseif bombEntry.variant == BombVariant.BOMB_ROCKET then
    base = base * 1.2
  end

  return base
end

local function update_overlay(state, tracked)
  local lines = {}
  for _, entry in ipairs(tracked) do
    table.insert(lines, string.format("bomb@%d rad=%.0f fuse=%d", entry.id or 0, entry.radius, entry.fuse))
  end
  state.bombs.overlay = lines
end

function Bombs.init(state)
  ensure_state(state)
end

function Bombs.update(state)
  ensure_state(state)
  local tracked = clear_array(state.bombs.tracked)
  local avoidance = clear_array(state.bombs.avoidance)
  local playerSnapshot = state.percepts.player
  local bombs = state.percepts.bombs or {}
  local enemies = state.percepts.enemies or {}

  local playerPos = playerSnapshot and playerSnapshot.position
  local requestRemote = false

  for _, bombEntry in ipairs(bombs) do
    local radius = compute_radius(bombEntry, playerSnapshot)
    local fuse = bombEntry.timeout or 0
    local avoidanceEntry = {
      position = bombEntry.position,
      radius = radius + 35,
      fuse = fuse,
      owner = bombEntry.owner,
      variant = bombEntry.variant,
      id = bombEntry.id,
    }
    table.insert(tracked, avoidanceEntry)
    table.insert(avoidance, avoidanceEntry)

    if playerSnapshot and playerSnapshot.active and playerSnapshot.active.id == CollectibleType.COLLECTIBLE_REMOTE_DETONATOR then
      if fuse > 0 then
        local enemyInRange = false
        for _, enemy in ipairs(enemies) do
          if enemy.position and (enemy.position - bombEntry.position):Length() <= radius + 20 then
            enemyInRange = true
            break
          end
        end
        if enemyInRange and playerPos and (playerPos - bombEntry.position):Length() >= radius + 30 then
          requestRemote = true
        end
      end
    end
  end

  state.bombs.avoidance = avoidance
  state.memory = state.memory or {}
  state.memory.bombAvoidance = avoidance
  state.memory.requestRemoteDetonate = requestRemote
  update_overlay(state, tracked)
end

function Bombs.should_detonate(state)
  ensure_state(state)
  if not state.memory or not state.memory.requestRemoteDetonate then
    return false
  end
  if state.frame - (state.bombs.lastDetonateFrame or -120) < 45 then
    return false
  end
  state.bombs.lastDetonateFrame = state.frame
  return true
end

function Bombs.debug(state)
  ensure_state(state)
  return state.bombs.overlay or {}
end

return Bombs
