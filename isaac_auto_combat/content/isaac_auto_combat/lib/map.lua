--- Floor awareness module.
-- Keeps track of visited rooms and simple secret room candidates.

local Map = {}

local game = Game()

local function ensure_state(state)
  state.map = state.map or {
    visited = {},
    known = {},
    secretCandidates = {},
    superSecretCandidates = {},
    currentRoomIndex = nil,
  }
end

local function clear_array(arr)
  for i = #arr, 1, -1 do
    arr[i] = nil
  end
  return arr
end

function Map.init(state)
  ensure_state(state)
end

function Map.update(state)
  ensure_state(state)
  local level = game:GetLevel()
  local room = game:GetRoom()
  if level then
    state.map.stage = level:GetStage()
    state.map.roomCount = level:GetRooms() and level:GetRooms().Size or 0
    state.map.secretCandidates = clear_array(state.map.secretCandidates)
    state.map.superSecretCandidates = clear_array(state.map.superSecretCandidates)
  end

  if room then
    state.map.currentRoomIndex = level:GetCurrentRoomDesc().GridIndex
    state.map.currentRoomType = room:GetType()
  end

  local mapInfo = state.percepts.map or { rooms = {}, visited = {}, unvisited = {} }
  local visitedSet = state.map.visited
  for _, idx in ipairs(mapInfo.visited or {}) do
    visitedSet[idx] = true
  end

  for _, data in ipairs(mapInfo.rooms or {}) do
    if data.roomType == RoomType.ROOM_SECRET and not data.visited then
      table.insert(state.map.secretCandidates, data.index)
    elseif data.roomType == RoomType.ROOM_SUPERSECRET and not data.visited then
      table.insert(state.map.superSecretCandidates, data.index)
    elseif not visitedSet[data.index] and data.roomType == RoomType.ROOM_DEFAULT then
      table.insert(state.map.secretCandidates, data.index)
    end
  end
end

local function count_entries(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

function Map.debug(state)
  ensure_state(state)
  return {
    string.format("rooms=%d", state.map.roomCount or 0),
    string.format("visited=%d", count_entries(state.map.visited)),
  }
end

return Map
