--- Dynamic firestyle handler.
-- Extracts firing capabilities from player state and computes micro-policy knobs.

local Firestyle = {}

local game = Game()

local function ensure_module_state(state)
  state.firestyle = state.firestyle or {
    cache = {
      capabilities = {},
      policy = {},
    },
    overlay = {},
  }
end

local function weapon_capabilities(player)
  local capabilities = {}
  if not player then
    return capabilities
  end

  local weaponTypes = {
    brimstone = WeaponType.WEAPON_BRIMSTONE,
    techx = WeaponType.WEAPON_TECH_X,
    knife = WeaponType.WEAPON_KNIFE,
    fetus = WeaponType.WEAPON_FETUS,
    epic = WeaponType.WEAPON_EPIC_FETUS,
    ludo = WeaponType.WEAPON_LUDOVICO_TECHNIQUE,
    familiar = WeaponType.WEAPON_FAMILIAR,
    brimlaser = WeaponType.WEAPON_TECH_SWORD,
  }

  for key, weaponType in pairs(weaponTypes) do
    local ok = false
    if player.HasWeaponType then
      ok = player:HasWeaponType(weaponType)
    elseif weaponType == WeaponType.WEAPON_BRIMSTONE then
      ok = player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)
    end
    capabilities[key] = ok
  end

  return capabilities
end

local function compute_explosive_radius(state, snapshot)
  if not snapshot then
    return 0
  end

  local tearFlags = snapshot.tearFlags or 0
  local radius = 0
  local explosiveFlags = TearFlags.TEAR_EXPLOSIVE | TearFlags.TEAR_BOMBS
  if (tearFlags & explosiveFlags) ~= 0 then
    radius = 90
  end

  if (tearFlags & TearFlags.TEAR_BURN) ~= 0 then
    radius = math.max(radius, 70)
  end

  if radius > 0 then
    radius = radius + (snapshot.shotSpeed or 1) * 15
  end

  if snapshot.bombs and snapshot.bombs.mrMega then
    radius = radius * 1.8
  end

  return radius
end

local function nearest_wall_distance(room, pos)
  if not room or not pos then
    return math.huge
  end

  local clamped = room:GetClampedPosition(pos, 0)
  return (pos - clamped):Length()
end

local function compute_capabilities(state, player, snapshot)
  local cap = state.capabilities or {}
  for k in pairs(cap) do
    cap[k] = nil
  end

  if not player or not snapshot then
    return cap
  end

  local weapon = weapon_capabilities(player)
  cap.charge = weapon.brimstone or weapon.techx or snapshot.fireDelay > 10
  cap.brim = weapon.brimstone
  cap.techx = weapon.techx
  cap.knife = weapon.knife
  cap.ludo = weapon.ludo
  cap.fetus = weapon.fetus
  cap.epicFetus = weapon.epic
  cap.familiarPrimary = weapon.familiar
  cap.spectral = ((snapshot.tearFlags or 0) & TearFlags.TEAR_SPECTRAL) ~= 0
  cap.piercing = ((snapshot.tearFlags or 0) & TearFlags.TEAR_PIERCING) ~= 0
  cap.homing = ((snapshot.tearFlags or 0) & TearFlags.TEAR_HOMING) ~= 0
  cap.explosiveRadius = compute_explosive_radius(state, snapshot)
  cap.immuneExplosion = snapshot.hasHostHat or snapshot.hasPyromaniac
  cap.canHoldFire = cap.charge or cap.knife or weapon.brimlaser

  state.capabilities = cap
  return cap
end

local function diff_tables(a, b)
  if a == nil or b == nil then
    return true
  end
  local checked = {}
  for k, v in pairs(a) do
    if b[k] ~= v then
      return true
    end
    checked[k] = true
  end
  for k, v in pairs(b) do
    if not checked[k] and a[k] ~= v then
      return true
    end
  end
  return false
end

local function build_policy(state, cap, snapshot)
  local policy = state.firepolicy or {}
  policy.aim_mode = "DIRECT"
  policy.needs_hold = cap.canHoldFire or false
  policy.release_threshold = cap.charge and 0.82 or 0
  policy.melee_range = cap.knife and 80 or 0
  policy.disc_target = state.memory and state.memory.discTarget or nil
  policy.dodge_radius = math.max(60, (cap.explosiveRadius or 0) + 30)
  policy.suppress_reason = nil
  policy.self_danger = 0

  local room = game:GetRoom()
  if cap.explosiveRadius and cap.explosiveRadius > 0 then
    local wallDistance = nearest_wall_distance(room, snapshot and snapshot.position)
    if wallDistance < (cap.explosiveRadius + 25) and not cap.immuneExplosion then
      policy.suppress_reason = "self-danger"
      policy.self_danger = cap.explosiveRadius - wallDistance
    end
  end

  return policy
end

local function update_overlay(state, cap, policy)
  local lines = {}
  table.insert(lines, string.format("charge=%s", tostring(cap.charge)))
  table.insert(lines, string.format("knife=%s", tostring(cap.knife)))
  table.insert(lines, string.format("ludo=%s", tostring(cap.ludo)))
  table.insert(lines, string.format("fetus=%s", tostring(cap.fetus or cap.epicFetus)))
  table.insert(lines, string.format("explRadius=%.1f", cap.explosiveRadius or 0))
  if policy.suppress_reason then
    table.insert(lines, string.format("suppress=%s", policy.suppress_reason))
  end
  state.firestyle.overlay = lines
end

function Firestyle.init(state)
  ensure_module_state(state)
end

function Firestyle.update(state, player)
  ensure_module_state(state)
  local snapshot = state.percepts.player
  local cap = compute_capabilities(state, player, snapshot)
  local policy = build_policy(state, cap, snapshot)

  local cache = state.firestyle.cache
  if diff_tables(cache.capabilities, cap) or diff_tables(cache.policy, policy) then
    cache.capabilities = {}
    cache.policy = {}
    for k, v in pairs(cap) do
      cache.capabilities[k] = v
    end
    for k, v in pairs(policy) do
      cache.policy[k] = v
    end
  end

  state.firepolicy = policy
  update_overlay(state, cap, policy)
end

function Firestyle.debug(state)
  ensure_module_state(state)
  return state.firestyle.overlay or {}
end

return Firestyle
