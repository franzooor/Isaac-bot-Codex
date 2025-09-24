--- Economy brain.
-- Maintains resource reserves and simple opportunity cost tracking.

local Economy = {}

local game = Game()

local function ensure_state(state)
  state.economy = state.economy or {
    reserves = {
      bombs = 0,
      keys = 0,
      coins = 0,
      hearts = 0,
    },
    mode = "Balanced",
    realizedEV = 0,
    lastSpend = "",
  }
end

local function combined_hearts(snapshot)
  if not snapshot then
    return 0
  end
  return (snapshot.redHearts or 0) + (snapshot.soulHearts or 0) + (snapshot.blackHearts or 0)
end

function Economy.init(state)
  ensure_state(state)
end

function Economy.update(state, player)
  ensure_state(state)
  local snapshot = state.percepts.player
  if snapshot then
    state.economy.reserves.bombs = player and player:GetNumBombs() or (snapshot.bombs and snapshot.bombs.count) or 0
    state.economy.reserves.keys = player and player:GetNumKeys() or 0
    state.economy.reserves.coins = player and player:GetNumCoins() or 0
    state.economy.reserves.hearts = combined_hearts(snapshot)
  end

  local floorDepth = game:GetLevel():GetStage()
  if floorDepth >= LevelStage.STAGE4_1 then
    state.economy.mode = "Efficiency"
  elseif state.economy.reserves.hearts < 6 then
    state.economy.mode = "Safety"
  else
    state.economy.mode = "Balanced"
  end
end

function Economy.note_spend(state, resource, description)
  ensure_state(state)
  state.economy.lastSpend = string.format("%s -> %s", resource, description)
end

function Economy.adjust_ev(state, value)
  ensure_state(state)
  state.economy.realizedEV = (state.economy.realizedEV or 0) + value
end

function Economy.debug(state)
  ensure_state(state)
  local reserves = state.economy.reserves
  return {
    string.format("bombs=%d keys=%d coins=%d hearts=%d", reserves.bombs or 0, reserves.keys or 0, reserves.coins or 0, reserves.hearts or 0),
    string.format("mode=%s ev=%.2f", state.economy.mode or "Balanced", state.economy.realizedEV or 0),
    string.format("last=%s", state.economy.lastSpend or ""),
  }
end

return Economy
