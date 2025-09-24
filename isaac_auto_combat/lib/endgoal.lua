--- Endgoal tracking module.
-- Maintains run objectives and prerequisite checklists.

local Endgoal = {}

local game = Game()

local goalDefs = {
  ["Boss Rush"] = { timeLimit = 20 * 60, pace = "rush" },
  ["Hush"] = { timeLimit = 30 * 60, pace = "rush" },
  ["Mega Satan"] = { requiresKeyPieces = true },
  ["Satan"] = {},
  ["Isaac"] = { requiresPolaroid = true },
  ["Blue Baby"] = { requiresPolaroid = true },
  ["Mother"] = { requiresKnifePieces = true },
  ["Beast"] = { requiresAscent = true },
  ["Delirium"] = {},
  ["Greed"] = {},
}

local function ensure_state(state)
  state.endgoal = state.endgoal or {
    name = nil,
    checklist = "",
    pace = "balanced",
  }
end

function Endgoal.init(state)
  ensure_state(state)
end

function Endgoal.set(state, name)
  ensure_state(state)
  state.endgoal.name = name
end

local function check_collectible(player, collectible)
  if not player then
    return false
  end
  return player:HasCollectible(collectible)
end

local function format_bool(label, value)
  return string.format("%s:%s", label, value and "✔" or "✘")
end

function Endgoal.update(state, player)
  ensure_state(state)
  if not state.endgoal.name then
    state.endgoal.checklist = ""
    state.endgoal.pace = "balanced"
    return
  end

  local def = goalDefs[state.endgoal.name] or {}
  local pieces = {}

  if def.requiresPolaroid then
    table.insert(pieces, format_bool("Polaroid", check_collectible(player, CollectibleType.COLLECTIBLE_POLAROID)))
  end
  if def.requiresKeyPieces then
    local piece1 = check_collectible(player, CollectibleType.COLLECTIBLE_KEY_PIECE_1)
    local piece2 = check_collectible(player, CollectibleType.COLLECTIBLE_KEY_PIECE_2)
    table.insert(pieces, format_bool("Key1", piece1))
    table.insert(pieces, format_bool("Key2", piece2))
  end
  if def.requiresKnifePieces then
    local piece1 = check_collectible(player, CollectibleType.COLLECTIBLE_KNIFE_PIECE_1)
    local piece2 = check_collectible(player, CollectibleType.COLLECTIBLE_KNIFE_PIECE_2)
    table.insert(pieces, format_bool("Knife1", piece1))
    table.insert(pieces, format_bool("Knife2", piece2))
  end
  if def.requiresAscent then
    local stage = game:GetLevel():GetStage()
    table.insert(pieces, format_bool("Ascent", stage >= LevelStage.STAGE7))
  end

  if def.timeLimit then
    local seconds = math.floor(game:GetFrameCount() / 30)
    local remaining = def.timeLimit - seconds
    table.insert(pieces, string.format("Time:%s", remaining > 0 and string.format("%dm%02ds", math.floor(remaining / 60), remaining % 60) or "missed"))
    state.endgoal.pace = remaining > 0 and def.pace or "cleanup"
  else
    state.endgoal.pace = def.pace or "balanced"
  end

  state.endgoal.checklist = table.concat(pieces, " | ")
end

function Endgoal.debug(state)
  ensure_state(state)
  if not state.endgoal.name then
    return { "goal: none" }
  end
  return { string.format("goal %s", state.endgoal.name), state.endgoal.checklist or "" }
end

return Endgoal
