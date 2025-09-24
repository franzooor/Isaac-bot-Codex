--- Item scoring module.
-- Evaluates collectible pedestals using stat deltas and simple heuristics.

local ItemScoring = {}

local config = Isaac.GetItemConfig()

local function ensure_state(state)
  state.item_scoring = state.item_scoring or {
    lastScore = nil,
    overlay = {},
  }
end

local function safe_field(entry, field)
  local ok, value = pcall(function()
    return entry[field]
  end)
  if ok then
    return value
  end
  return nil
end

local function get_stat_modifiers(entry)
  local ok, mods = pcall(function()
    return entry.StatModifiers
  end)
  if ok and mods then
    return mods
  end
  return {}
end

local function fire_rate_from_delay(delay)
  return 30 / math.max(1, delay + 1)
end

local function compute_dps_delta(player, entry)
  if not player or not entry then
    return 0
  end
  local mods = get_stat_modifiers(entry)
  local damageBonus = mods.Damage or 0
  local fireDelayBonus = mods.FireDelay or mods.MaxFireDelay or 0
  local damageMult = mods.DamageMultiplier or 1
  local tearMult = mods.TearMultiplier or 1
  local baseRate = fire_rate_from_delay(player.MaxFireDelay)
  local newDelay = math.max(0, player.MaxFireDelay - fireDelayBonus)
  local newRate = fire_rate_from_delay(newDelay) * tearMult
  local baseDps = player.Damage * baseRate
  local newDps = (player.Damage + damageBonus) * newRate * damageMult
  return newDps - baseDps
end

local function compute_ehp_delta(player, entry)
  if not entry then
    return 0
  end
  local maxHearts = safe_field(entry, "AddMaxHearts") or 0
  local soulHearts = safe_field(entry, "AddSoulHearts") or 0
  local blackHearts = safe_field(entry, "AddBlackHearts") or 0
  local boneHearts = safe_field(entry, "AddBoneHearts") or 0
  local goldenHearts = safe_field(entry, "AddGoldenHearts") or 0
  return maxHearts + soulHearts * 0.5 + blackHearts * 0.6 + boneHearts * 0.75 + goldenHearts * 0.6
end

local function synergy_bonus(state, entry)
  local mods = get_stat_modifiers(entry)
  local snapshot = state.percepts.player
  if not snapshot then
    return 0
  end
  local bonus = 0
  if (snapshot.tearFlags or 0) & TearFlags.TEAR_HOMING ~= 0 then
    if mods.TearFlags and (mods.TearFlags & TearFlags.TEAR_SPECTRAL) ~= 0 then
      bonus = bonus + 0.5
    end
  end
  if (snapshot.tearFlags or 0) & TearFlags.TEAR_PIERCING ~= 0 then
    if mods.TearFlags and (mods.TearFlags & TearFlags.TEAR_HOMING) ~= 0 then
      bonus = bonus + 0.3
    end
  end
  if state.capabilities and state.capabilities.explosiveRadius and state.capabilities.explosiveRadius > 0 then
    if mods.Damage and mods.Damage > 1 then
      bonus = bonus + 0.4
    end
  end
  return bonus
end

local function danger_penalty(state, entry)
  local snapshot = state.percepts.player
  if not snapshot then
    return 0
  end
  local mods = get_stat_modifiers(entry)
  local tearFlags = mods.TearFlags or safe_field(entry, "TearFlags") or 0
  local penalty = 0
  if (tearFlags & TearFlags.TEAR_EXPLOSIVE) ~= 0 and not (state.capabilities and state.capabilities.immuneExplosion) then
    penalty = penalty + 2
  end
  if (tearFlags & TearFlags.TEAR_GREED_COIN) ~= 0 then
    penalty = penalty + 0.4
  end
  return penalty
end

local function evaluate_collectible(state, player, collectibleId)
  if collectibleId == 0 then
    return nil
  end
  local entry = config:GetCollectible(collectibleId)
  if not entry then
    return nil
  end
  local dps = compute_dps_delta(player, entry)
  local ehp = compute_ehp_delta(player, entry)
  local bonus = synergy_bonus(state, entry)
  local penalty = danger_penalty(state, entry)
  local quality = safe_field(entry, "Quality") or 0
  local score = dps * 0.65 + ehp * 0.4 + bonus + quality * 0.2 - penalty
  return {
    id = collectibleId,
    score = score,
    dps = dps,
    ehp = ehp,
    bonus = bonus,
    penalty = penalty,
    quality = quality,
    name = entry.Name,
  }
end

function ItemScoring.init(state)
  ensure_state(state)
end

function ItemScoring.update(state, player)
  ensure_state(state)
  state.item_scoring.overlay = {}
  local best = nil
  for _, pickup in ipairs(state.percepts.pickups or {}) do
    if pickup.variant == PickupVariant.PICKUP_COLLECTIBLE then
      local score = evaluate_collectible(state, player, pickup.subtype)
      if score then
        if not best or score.score > best.score then
          best = score
        end
      end
    end
  end
  state.item_scoring.lastScore = best
  if best then
    table.insert(state.item_scoring.overlay, string.format("%s %.2f (dps %.2f ehp %.2f)", best.name or "item", best.score or 0, best.dps or 0, best.ehp or 0))
  end
end

function ItemScoring.debug(state)
  ensure_state(state)
  return state.item_scoring.overlay or {}
end

return ItemScoring
