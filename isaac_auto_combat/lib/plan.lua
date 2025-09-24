--- Planning module.
-- Chooses high level goals after rooms are cleared.

local Plan = {}

local game = Game()

local function ensure_state(state)
  state.planning = state.planning or {
    activeGoal = nil,
    route = {},
    crumbs = {},
    needsReplan = true,
    lastPlanFrame = -120,
  }
end

local function clear_array(arr)
  for i = #arr, 1, -1 do
    arr[i] = nil
  end
  return arr
end

local function add_candidate(candidates, name, score, data)
  table.insert(candidates, {
    name = name,
    score = score,
    data = data,
  })
end

local function pick_best(candidates)
  table.sort(candidates, function(a, b)
    if a.score == b.score then
      return a.name < b.name
    end
    return a.score > b.score
  end)
  return candidates[1]
end

function Plan.init(state)
  ensure_state(state)
end

function Plan.flag_for_replan(state, reason)
  ensure_state(state)
  state.planning.needsReplan = true
  state.planning.replanReason = reason or "unknown"
end

function Plan.update(state)
  ensure_state(state)
  local room = game:GetRoom()
  local isClear = room and room:IsClear()
  if room then
    if state.planning.lastRoomClear == nil then
      state.planning.lastRoomClear = isClear
    elseif state.planning.lastRoomClear ~= isClear and isClear then
      state.planning.needsReplan = true
    end
    state.planning.lastRoomClear = isClear
  end

  if room and not isClear then
    return
  end

  if not state.planning.needsReplan and state.frame - (state.planning.lastPlanFrame or -120) < 30 then
    return
  end

  local candidates = {}
  local mapInfo = state.percepts.map or { rooms = {}, visited = {}, unvisited = {} }
  local unvisitedCount = #mapInfo.unvisited
  if unvisitedCount > 0 then
    add_candidate(candidates, "Explore", 2 + unvisitedCount * 0.05, { target = mapInfo.unvisited[1] })
  end

  local secretCandidates = state.map and state.map.secretCandidates or {}
  if secretCandidates and #secretCandidates > 0 then
    add_candidate(candidates, "Secret", 1.8, { target = secretCandidates[1] })
  end

  local deferred = state.memory.deferredPickups or {}
  if #deferred > 0 then
    add_candidate(candidates, "Deferred Loot", 1.6 + #deferred * 0.02, { list = deferred })
  end

  if state.endgoal and state.endgoal.name then
    add_candidate(candidates, state.endgoal.name .. " Prep", 2.4, { endgoal = state.endgoal.name })
  end

  local best = pick_best(candidates)
  if best then
    state.planning.activeGoal = best
    state.planning.route = {}
    if best.data and best.data.target then
      table.insert(state.planning.route, tostring(best.data.target))
    end
    state.planning.crumbs = clear_array(state.planning.crumbs)
    if best.data and best.data.list then
      for _, idx in ipairs(best.data.list) do
        table.insert(state.planning.crumbs, tostring(idx))
      end
    end
    state.planning.lastPlanFrame = state.frame
    state.planning.needsReplan = false
  else
    state.planning.activeGoal = nil
    state.planning.route = {}
  end
end

function Plan.active_goal(state)
  ensure_state(state)
  return state.planning.activeGoal
end

function Plan.debug(state)
  ensure_state(state)
  local lines = {}
  if state.planning.activeGoal then
    table.insert(lines, string.format("goal: %s (%.2f)", state.planning.activeGoal.name, state.planning.activeGoal.score or 0))
  else
    table.insert(lines, "goal: none")
  end
  if state.planning.route then
    table.insert(lines, string.format("route: %s", table.concat(state.planning.route, ",")))
  end
  if state.planning.crumbs and #state.planning.crumbs > 0 then
    table.insert(lines, "crumbs: " .. table.concat(state.planning.crumbs, ","))
  end
  return lines
end

return Plan
