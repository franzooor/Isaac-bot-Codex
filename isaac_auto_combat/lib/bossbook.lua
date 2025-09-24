--- Bossbook overrides.
-- Provides small hints for tricky bosses.

local BossBook = {}

local function ensure_state(state)
  state.bossbook = state.bossbook or {
    hint = nil,
  }
end

local bossHints = {
  [EntityType.ENTITY_BIG_HORN] = { tactic = "stay away from bombs", preferRange = true },
  [EntityType.ENTITY_MASK] = { tactic = "flank mask", flank = true },
  [EntityType.ENTITY_HEART] = { tactic = "hug heart lane", lane = true },
  [EntityType.ENTITY_MOMS_HEART] = { tactic = "stay center lanes", lane = true },
  [EntityType.ENTITY_HUSH] = { tactic = "long range dodge", maxRange = true },
  [EntityType.ENTITY_MEGA_SATAN] = { tactic = "avoid hands", maxRange = true },
  [EntityType.ENTITY_ULTRA_GREED] = { tactic = "stun windows", preferRange = true },
}

function BossBook.init(state)
  ensure_state(state)
end

function BossBook.update(state)
  ensure_state(state)
  state.bossbook.hint = nil
  for _, enemy in ipairs(state.percepts.enemies or {}) do
    local hint = bossHints[enemy.type]
    if hint then
      state.bossbook.hint = {
        entity = enemy.type,
        tactic = hint.tactic,
        preferRange = hint.preferRange,
        flank = hint.flank,
        lane = hint.lane,
        maxRange = hint.maxRange,
      }
      break
    end
  end
end

function BossBook.current_hint(state)
  ensure_state(state)
  return state.bossbook.hint
end

function BossBook.debug(state)
  ensure_state(state)
  if not state.bossbook.hint then
    return { "boss: none" }
  end
  return { string.format("boss: %s", state.bossbook.hint.tactic or "") }
end

return BossBook
