--- Tactical controller for the auto combat mod.
-- Responsible for translating perception data from the room into intents
-- that the act module can turn into button presses.

local Controller = {}

local game = Game()

local MAX_AVOID_DISTANCE = 140
local APPROACH_DISTANCE = 260
local RETREAT_DISTANCE = 120

local function ensure_module_state(state)
  state.controller = state.controller or {
    targetHash = nil,
    targetDistance = 0,
    enemyCount = 0,
    projectileCount = 0,
    moveVector = Vector(0, 0),
    shootVector = Vector(0, 0),
    avoidanceVector = Vector(0, 0),
  }
end

local function zero_controller_vectors(state)
  if not state or not state.controller then
    return
  end

  state.controller.targetHash = nil
  state.controller.targetDistance = 0
  state.controller.moveVector = Vector(0, 0)
  state.controller.shootVector = Vector(0, 0)
  state.controller.avoidanceVector = Vector(0, 0)
end

local function reset_intent(intent)
  if not intent then
    return
  end

  intent.move = Vector(0, 0)
  intent.shoot = Vector(0, 0)
  intent.fire = false
end

local function vector_length_squared(vec)
  return (vec.X * vec.X) + (vec.Y * vec.Y)
end

local function clamp_vector(vec)
  local lengthSq = vector_length_squared(vec)
  if lengthSq > 1 then
    local length = math.sqrt(lengthSq)
    if length > 0 then
      return Vector(vec.X / length, vec.Y / length)
    end
  end
  if lengthSq < 1e-4 then
    return Vector(0, 0)
  end
  return vec
end

local function gather_threats(player)
  local enemies = {}
  local projectiles = {}
  local entities = Isaac.GetRoomEntities()

  for _, entity in ipairs(entities) do
    if entity and entity:Exists() then
      if entity:IsVulnerableEnemy() and entity:IsActiveEnemy(false) and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
        table.insert(enemies, entity)
      elseif entity.Type == EntityType.ENTITY_PROJECTILE then
        table.insert(projectiles, entity)
      end
    end
  end

  return enemies, projectiles
end

local function find_primary_target(playerPos, enemies)
  local closest = nil
  local closestDistSq = nil

  for _, enemy in ipairs(enemies) do
    if enemy and enemy:Exists() and not enemy:IsDead() then
      local diff = enemy.Position - playerPos
      local distSq = vector_length_squared(diff)
      if not closest or distSq < closestDistSq then
        closest = enemy
        closestDistSq = distSq
      end
    end
  end

  return closest, closestDistSq and math.sqrt(closestDistSq) or 0
end

local function compute_projectile_avoidance(playerPos, projectiles)
  local avoidance = Vector(0, 0)

  for _, proj in ipairs(projectiles) do
    if proj and proj:Exists() then
      local toPlayer = playerPos - proj.Position
      local distSq = vector_length_squared(toPlayer)
      if distSq > 0 and distSq < (MAX_AVOID_DISTANCE * MAX_AVOID_DISTANCE) then
        local dist = math.sqrt(distSq)
        local direction = Vector(toPlayer.X / dist, toPlayer.Y / dist)
        local velocity = proj.Velocity
        local speedSq = vector_length_squared(velocity)
        local weight = 0.25 + (MAX_AVOID_DISTANCE - dist) / MAX_AVOID_DISTANCE

        if speedSq > 0 then
          local speed = math.sqrt(speedSq)
          local velDir = Vector(velocity.X / speed, velocity.Y / speed)
          local dot = (velDir.X * direction.X) + (velDir.Y * direction.Y)
          if dot > 0.35 then
            avoidance = avoidance + (direction * (weight * dot))
          end
        else
          avoidance = avoidance + (direction * weight)
        end
      end
    end
  end

  return avoidance
end

local function compute_strafe_vector(toEnemyNormal, frame)
  local strafeSign = ((math.floor(frame / 90) % 2) == 0) and 1 or -1
  return Vector(toEnemyNormal.Y * strafeSign, -toEnemyNormal.X * strafeSign)
end

function Controller.init(state)
  ensure_module_state(state)
end

function Controller.reset(state)
  ensure_module_state(state)

  if state.intent then
    reset_intent(state.intent)
  end

  zero_controller_vectors(state)
  state.controller.enemyCount = 0
  state.controller.projectileCount = 0
  state.controller.targetDistance = 0
end

function Controller.update(state)
  if not state then
    return
  end

  ensure_module_state(state)

  local intent = state.intent
  if not intent then
    return
  end

  if not state.enabled then
    reset_intent(intent)
    zero_controller_vectors(state)
    return
  end

  local player = Isaac.GetPlayer(0)
  if not player then
    reset_intent(intent)
    zero_controller_vectors(state)
    return
  end

  local room = game:GetRoom()
  if not room or room:IsClear() then
    reset_intent(intent)
    state.mode = "idle"
    state.controller.enemyCount = 0
    state.controller.projectileCount = 0
    zero_controller_vectors(state)
    return
  end

  local playerPos = player.Position
  local enemies, projectiles = gather_threats(player)

  state.controller.enemyCount = #enemies
  state.controller.projectileCount = #projectiles

  if #enemies == 0 then
    reset_intent(intent)
    state.mode = "idle"
    zero_controller_vectors(state)
    return
  end

  local target, targetDistance = find_primary_target(playerPos, enemies)
  state.controller.targetDistance = targetDistance

  if not target then
    reset_intent(intent)
    state.mode = "idle"
    zero_controller_vectors(state)
    return
  end

  local toEnemy = target.Position - playerPos
  local toEnemyLengthSq = vector_length_squared(toEnemy)
  local toEnemyNormal = Vector(0, 0)
  if toEnemyLengthSq > 0 then
    local len = math.sqrt(toEnemyLengthSq)
    toEnemyNormal = Vector(toEnemy.X / len, toEnemy.Y / len)
  end

  local shootVector = Vector(toEnemyNormal.X, toEnemyNormal.Y)
  local moveVector = Vector(0, 0)

  if targetDistance > 0 then
    if targetDistance < RETREAT_DISTANCE then
      moveVector = moveVector - toEnemyNormal * ((RETREAT_DISTANCE - targetDistance) / RETREAT_DISTANCE)
    elseif targetDistance > APPROACH_DISTANCE then
      moveVector = moveVector + toEnemyNormal * ((targetDistance - APPROACH_DISTANCE) / APPROACH_DISTANCE)
    else
      local strafe = compute_strafe_vector(toEnemyNormal, state.frame or 0)
      moveVector = moveVector + (strafe * 0.85)
    end
  end

  local avoidance = compute_projectile_avoidance(playerPos, projectiles)
  state.controller.avoidanceVector = avoidance

  moveVector = moveVector + (avoidance * 1.5)

  moveVector = clamp_vector(moveVector)

  state.mode = "combat"
  state.controller.targetHash = GetPtrHash(target)
  state.controller.moveVector = moveVector
  state.controller.shootVector = shootVector

  intent.move = Vector(moveVector.X, moveVector.Y)
  intent.shoot = Vector(shootVector.X, shootVector.Y)
  intent.fire = vector_length_squared(shootVector) > 0
end

function Controller.debug(state)
  if not state or not state.controller then
    return { "controller offline" }
  end

  local lines = {}
  table.insert(lines, string.format("enemies=%d", state.controller.enemyCount or 0))
  table.insert(lines, string.format("projectiles=%d", state.controller.projectileCount or 0))
  table.insert(lines, string.format("target=%s", tostring(state.controller.targetHash)))
  table.insert(lines, string.format("distance=%.1f", state.controller.targetDistance or 0))
  table.insert(lines, string.format("move=(%.2f, %.2f)", state.controller.moveVector.X, state.controller.moveVector.Y))
  table.insert(lines, string.format("shoot=(%.2f, %.2f)", state.controller.shootVector.X, state.controller.shootVector.Y))
  table.insert(lines, string.format("avoid=(%.2f, %.2f)", state.controller.avoidanceVector.X, state.controller.avoidanceVector.Y))

  return lines
end

return Controller
