--- Room min/max module.
-- Looks for environmental opportunities after a room is cleared.

local RoomMinMax = {}

local function ensure_state(state)
  state.roomminmax = state.roomminmax or {
    targets = {},
    lastScanRoom = nil,
  }
end

local function is_tinted(gridType)
  return gridType == GridEntityType.GRID_ROCKB or gridType == GridEntityType.GRID_ROCK_ALT or gridType == GridEntityType.GRID_ROCKT
end

local function is_special_grid(gridType)
  return gridType == GridEntityType.GRID_FIREPLACE or gridType == GridEntityType.GRID_POOP or gridType == GridEntityType.GRID_SKULL
end

local function clear_array(arr)
  for i = #arr, 1, -1 do
    arr[i] = nil
  end
  return arr
end

function RoomMinMax.init(state)
  ensure_state(state)
end

function RoomMinMax.update(state)
  ensure_state(state)
  local room = Game():GetRoom()
  if not room or not room:IsClear() then
    return
  end

  local roomIndex = Game():GetLevel():GetCurrentRoomDesc().GridIndex
  if state.roomminmax.lastScanRoom == roomIndex and state.frame - (state.roomminmax.lastScanFrame or -120) < 30 then
    return
  end

  state.roomminmax.targets = clear_array(state.roomminmax.targets)
  for _, grid in ipairs(state.percepts.grid or {}) do
    if grid and (is_tinted(grid.type) or is_special_grid(grid.type)) then
      table.insert(state.roomminmax.targets, grid.index)
    end
  end

  state.roomminmax.lastScanRoom = roomIndex
  state.roomminmax.lastScanFrame = state.frame
end

function RoomMinMax.targets(state)
  ensure_state(state)
  return state.roomminmax.targets
end

function RoomMinMax.debug(state)
  ensure_state(state)
  return { string.format("minmax targets=%d", #(state.roomminmax.targets or {})) }
end

return RoomMinMax
