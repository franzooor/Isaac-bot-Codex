--- Decision maker.
-- Chooses movement, aiming, and item usage based on percepts and policies.

local Decide = {}

local bombs = require("isaac_auto_combat.lib.bombs")
local heals = require("isaac_auto_combat.lib.heals")
local loot = require("isaac_auto_combat.lib.loot")
local bossbook = require("isaac_auto_combat.lib.bossbook")
local plan = require("isaac_auto_combat.lib.plan")

local game = Game()

local movementDirections = {
  { name = "idle", vector = Vector(0, 0) },
  { name = "up", vector = Vector(0, -1) },
  { name = "down", vector = Vector(0, 1) },
  { name = "left", vector = Vector(-1, 0) },
  { name = "right", vector = Vector(1, 0) },
  { name = "up_left", vector = Vector(-1, -1) },
  { name = "up_right", vector = Vector(1, -1) },
  { name = "down_left", vector = Vector(-1, 1) },
  { name = "down_right", vector = Vector(1, 1) },
}

local function ensure_state(state)
  state.decide = state.decide or {
    lastActiveUse = -240,
    lastTargetId = nil,
    lastMode = "TRANSIT",
    topMove = { name = "idle", score = 0 },
  }
end

local function vector_length(v)
  return math.sqrt(v.X * v.X + v.Y * v.Y)
end

local function normalise(vec)
  if vec.X == 0 and vec.Y == 0 then
    return Vector(0, 0)
  end
  return vec:Resized(1)
end

local function choose_target(state, playerPos)
  local best = nil
  local bestDist = math.huge
  local room = game:GetRoom()

  for _, enemy in ipairs(state.percepts.enemies or {}) do
    local dist = (enemy.position - playerPos):LengthSquared()
    local hasLos = room and room:CheckLine(playerPos, enemy.position, GridCollisionClass.COLLISION_PIT)
    local weighted = dist * (hasLos and 0.9 or 1.2)
    if weighted < bestDist then
      bestDist = weighted
      best = enemy
    end
  end

  if best then
    state.decide.lastTargetId = best.id
  end
  return best
end

local function projectile_hazard_score(candidatePos, projectiles)
  local penalty = 0
  for _, projectile in ipairs(projectiles or {}) do
    local future = projectile.position + projectile.velocity * 10
    local dist = (future - candidatePos):Length()
    if dist < 40 then
      penalty = penalty + (40 - dist) * 1.5
    end
  end
  return penalty
end

local function bomb_hazard_score(candidatePos, avoidance)
  local penalty = 0
  for _, entry in ipairs(avoidance or {}) do
    local dist = (candidatePos - entry.position):Length()
    if dist < entry.radius then
      penalty = penalty + (entry.radius - dist) * 2.5
    end
  end
  return penalty
end

local function wall_penalty(room, candidatePos)
  if not room then
    return 0
  end
  if not room:IsPositionInRoom(candidatePos, 0) then
    return 50
  end
  return 0
end

local function target_score(direction, playerPos, target, hint)
  if not target then
    return 0
  end
  local candidate = playerPos + direction * 40
  local distNow = (target.position - playerPos):Length()
  local distFuture = (target.position - candidate):Length()
  local score = (distNow - distFuture) * 0.5
  if hint and hint.preferRange then
    score = score - (distFuture < 120 and 2 or 0)
  elseif hint and hint.maxRange then
    score = score - (distFuture < 180 and 3 or 0)
  elseif hint and hint.flank then
    local toTarget = normalise(target.position - playerPos)
    local dirNormal = Vector(-toTarget.Y, toTarget.X)
    local dot = direction.X * dirNormal.X + direction.Y * dirNormal.Y
    score = score + (dot * 0.3)
  end
  return score
end

local function heal_score(direction, playerPos, healTarget)
  if not healTarget then
    return 0
  end
  local candidate = playerPos + direction * 40
  local distNow = (healTarget.position - playerPos):Length()
  local distFuture = (healTarget.position - candidate):Length()
  return (distNow - distFuture) * 0.75
end

local function loot_score(direction, playerPos, lootTarget)
  if not lootTarget then
    return 0
  end
  local candidate = playerPos + direction * 40
  local distNow = (lootTarget.position - playerPos):Length()
  local distFuture = (lootTarget.position - candidate):Length()
  return (distNow - distFuture) * 0.5
end

local function pick_direction(state, playerPos, target, healTarget, lootTarget)
  local room = game:GetRoom()
  local hint = bossbook.current_hint(state)
  local avoidance = state.memory.bombAvoidance or {}
  local projectiles = state.percepts.projectiles or {}
  local best = { name = "idle", vector = Vector(0, 0), score = -math.huge }

  for _, entry in ipairs(movementDirections) do
    local vector = normalise(entry.vector)
    local candidate = playerPos + vector * 35
    local score = 0
    score = score + target_score(vector, playerPos, target, hint)
    score = score + heal_score(vector, playerPos, healTarget)
    score = score + loot_score(vector, playerPos, lootTarget)
    score = score - projectile_hazard_score(candidate, projectiles)
    score = score - bomb_hazard_score(candidate, avoidance)
    score = score - wall_penalty(room, candidate)
    if vector_length(vector) < 0.1 then
      score = score - 0.2
    end

    if score > best.score then
      best = {
        name = entry.name,
        vector = vector,
        score = score,
      }
    end
  end

  state.decide.topMove = best
  return best
end

local function update_mode(state, target, room)
  if target then
    state.mode = "COMBAT"
  else
    if room and room:IsClear() then
      if state.loot and state.loot.target then
        state.mode = "LOOT"
      else
        state.mode = "TRANSIT"
      end
    else
      state.mode = "TRANSIT"
    end
  end
end

local function aim_at_target(intent, policy, playerPos, target)
  if not target then
    intent.shoot = Vector(0, 0)
    intent.fire = false
    return
  end
  local toTarget = target.position - playerPos
  local distance = toTarget:Length()
  if distance < 0.01 then
    intent.shoot = Vector(0, 0)
  else
    intent.shoot = toTarget:Resized(1)
  end
  if policy.melee_range and policy.melee_range > 0 and distance > policy.melee_range then
    intent.fire = false
  else
    intent.fire = policy.suppress_reason == nil
  end
end

local function update_active_usage(state, snapshot)
  state.intent.useActive = false
  if not snapshot or not snapshot.active then
    return
  end
  if snapshot.active.charge < snapshot.active.maxCharge or snapshot.active.maxCharge == 0 then
    return
  end
  if state.mode ~= "COMBAT" then
    return
  end
  if state.frame - (state.decide.lastActiveUse or -240) < 120 then
    return
  end
  state.intent.useActive = true
  state.decide.lastActiveUse = state.frame
end

local function update_remote_bomb(state)
  if bombs.should_detonate(state) then
    state.intent.useActive = true
  end
end

local function handle_submodes(state, healTarget)
  if healTarget and state.submode == "HEAL" then
    return
  end
  if state.submode == "HEAL" and not healTarget then
    state.submode = nil
  end
end

function Decide.update(state, player)
  ensure_state(state)
  local intent = state.intent
  intent.move = intent.move or Vector(0, 0)
  intent.shoot = intent.shoot or Vector(0, 0)
  intent.fire = intent.fire or false
  intent.useActive = false
  intent.useBomb = false

  if not state.enabled then
    intent.move = Vector(0, 0)
    intent.shoot = Vector(0, 0)
    intent.fire = false
    return
  end

  local snapshot = state.percepts.player
  local playerPos = snapshot and snapshot.position
  if not playerPos then
    return
  end

  local room = game:GetRoom()
  local target = choose_target(state, playerPos)
  local healTarget = heals.current_target(state)
  local lootTarget = loot.current_target(state)
  handle_submodes(state, healTarget)

  update_mode(state, target, room)

  if state.submode == "HEAL" and healTarget then
    target = nil
  end

  local bestMove = pick_direction(state, playerPos, target, healTarget, lootTarget)
  intent.move = bestMove.vector

  local policy = state.firepolicy or {}
  if policy.suppress_reason then
    intent.fire = false
    intent.shoot = Vector(0, 0)
  else
    aim_at_target(intent, policy, playerPos, target)
  end

  update_active_usage(state, snapshot)
  update_remote_bomb(state)

  local activeGoal = plan.active_goal and plan.active_goal(state)
  if activeGoal then
    state.decide.activeGoal = activeGoal.name
  else
    state.decide.activeGoal = nil
  end

  state.decide.target = target and target.id or nil
  state.decide.targetDistance = target and (target.position - playerPos):Length() or math.huge
end

return Decide
