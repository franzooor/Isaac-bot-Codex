--- Perception system for the auto combat bot.
-- Builds lightweight snapshots of the player, room entities, and map metadata.

local Sense = {}

local game = Game()

local function clear_array(arr)
  if not arr then
    return {}
  end

  for i = #arr, 1, -1 do
    arr[i] = nil
  end

  return arr
end

local function clear_table(tbl)
  if not tbl then
    return {}
  end

  for k in pairs(tbl) do
    tbl[k] = nil
  end

  return tbl
end

local function safe_vector(vec)
  if vec then
    return Vector(vec.X, vec.Y)
  end
  return Vector(0, 0)
end

local function capture_player_snapshot(state, player)
  local snapshot = state.percepts.player or {}
  snapshot.exists = player ~= nil

  if not player then
    state.percepts.player = snapshot
    return
  end

  local effects = player:GetEffects()
  snapshot.position = safe_vector(player.Position)
  snapshot.velocity = safe_vector(player.Velocity)
  snapshot.speed = player.MoveSpeed
  snapshot.luck = player.Luck
  snapshot.damage = player.Damage
  snapshot.fireDelay = player.MaxFireDelay
  snapshot.shotSpeed = player.ShotSpeed
  snapshot.range = player.TearRange
  snapshot.tearFlags = player.TearFlags
  snapshot.tearVariant = player.TearVariant
  snapshot.canFly = player.CanFly
  snapshot.flying = player:HasCollectible(CollectibleType.COLLECTIBLE_FLIGHT) or player.CanFly
  snapshot.hitPoints = player.HitPoints
  snapshot.redHearts = player:GetHearts()
  snapshot.maxHearts = player:GetMaxHearts()
  snapshot.soulHearts = player:GetSoulHearts()
  snapshot.blackHearts = player:GetBlackHearts()
  snapshot.boneHearts = player:GetBoneHearts()
  snapshot.eternalHearts = player:GetEternalHearts()
  snapshot.rottenHearts = player:GetRottenHearts()
  snapshot.playerType = player:GetPlayerType()
  snapshot.familiars = clear_array(snapshot.familiars or {})
  snapshot.invincibilityFrames = player.FrameCooldown
  snapshot.hasHostHat = player:HasCollectible(CollectibleType.COLLECTIBLE_HOST_HAT)
  snapshot.hasPyromaniac = player:HasCollectible(CollectibleType.COLLECTIBLE_PYROMANIAC)

  snapshot.active = snapshot.active or {}
  snapshot.active.id = player:GetActiveItem()
  snapshot.active.charge = player:GetActiveCharge()
  snapshot.active.maxCharge = player:GetActiveMaxCharge()
  snapshot.active.battery = player:GetBatteryCharge()
  snapshot.active.itemConfig = player:GetActiveItem(ActiveSlot.SLOT_PRIMARY)

  snapshot.bombs = snapshot.bombs or {}
  snapshot.bombs.count = player:GetNumBombs()
  snapshot.bombs.mrMega = player:HasCollectible(CollectibleType.COLLECTIBLE_MR_MEGA)
  snapshot.bombs.bomberBoy = player:HasCollectible(CollectibleType.COLLECTIBLE_BOMBER_BOY)

  snapshot.defenses = snapshot.defenses or {}
  snapshot.defenses.hostHat = snapshot.hasHostHat
  snapshot.defenses.pyro = snapshot.hasPyromaniac
  snapshot.defenses.lostBrim = effects and effects:HasNullEffect(NullItemID.ID_LOST_CURSE) or false

  local familiars = Isaac.FindByType(EntityType.ENTITY_FAMILIAR)
  for _, familiar in ipairs(familiars) do
    if familiar and familiar.Parent and familiar.Parent:ToPlayer() == player then
      table.insert(snapshot.familiars, {
        id = familiar.InitSeed,
        type = familiar.Type,
        variant = familiar.Variant,
        subtype = familiar.SubType,
        position = safe_vector(familiar.Position),
        velocity = safe_vector(familiar.Velocity),
      })
    end
  end

  state.percepts.player = snapshot
end

local function gather_enemies(state, player)
  local enemies = state.percepts.enemies or {}
  enemies = clear_array(enemies)
  local projectiles = state.percepts.projectiles or {}
  projectiles = clear_array(projectiles)
  local lasers = state.percepts.lasers or {}
  lasers = clear_array(lasers)
  local creep = state.percepts.creep or {}
  creep = clear_array(creep)
  local bombs = state.percepts.bombs or {}
  bombs = clear_array(bombs)
  local pickups = state.percepts.pickups or {}
  pickups = clear_array(pickups)

  local entities = Isaac.GetRoomEntities()
  for _, entity in ipairs(entities) do
    if entity and entity:Exists() and not entity:IsDead() then
      if entity:IsVulnerableEnemy() and entity:IsActiveEnemy(false) and not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
        table.insert(enemies, {
          id = entity.InitSeed,
          ptr = GetPtrHash(entity),
          type = entity.Type,
          variant = entity.Variant,
          subtype = entity.SubType,
          position = safe_vector(entity.Position),
          velocity = safe_vector(entity.Velocity),
          hp = entity.HitPoints,
          maxhp = entity.MaxHitPoints,
          flags = entity:GetEntityFlags(),
        })
      elseif entity.Type == EntityType.ENTITY_PROJECTILE then
        table.insert(projectiles, {
          id = entity.InitSeed,
          position = safe_vector(entity.Position),
          velocity = safe_vector(entity.Velocity),
          height = entity.Height,
          fallingAccel = entity.FallingAccel,
          fallingSpeed = entity.FallingSpeed,
        })
      elseif entity.Type == EntityType.ENTITY_LASER then
        table.insert(lasers, {
          id = entity.InitSeed,
          position = safe_vector(entity.Position),
          rotation = entity:GetSpriteRotation(),
          timeout = entity.Timeout,
          angle = entity.Velocity:GetAngleDegrees(),
        })
      elseif entity.Type == EntityType.ENTITY_EFFECT then
        local effect = entity:ToEffect()
        if effect and effect.Variant == EffectVariant.CREEP then
          table.insert(creep, {
            id = entity.InitSeed,
            position = safe_vector(entity.Position),
            timeout = entity.Timeout,
            size = entity.Size,
          })
        end
      elseif entity.Type == EntityType.ENTITY_PICKUP then
        local pickup = entity:ToPickup()
        if pickup then
          table.insert(pickups, {
            id = entity.InitSeed,
            position = safe_vector(entity.Position),
            variant = pickup.Variant,
            subtype = pickup.SubType,
            price = pickup.Price,
            touched = pickup.Touched,
            wait = pickup.Wait,
            autoUpdatePrice = pickup.AutoUpdatePrice,
          })
        end
      elseif entity.Type == EntityType.ENTITY_BOMB then
        local bomb = entity:ToBomb()
        if bomb then
          local ok, countdown = pcall(function()
            return bomb:GetExplosionCountdown()
          end)
          table.insert(bombs, {
            id = entity.InitSeed,
            position = safe_vector(entity.Position),
            velocity = safe_vector(entity.Velocity),
            timeout = ok and countdown or entity.Timeout,
            radiusMultiplier = bomb.RadiusMultiplier,
            variant = bomb.Variant,
            isPlayerOwned = bomb.SpawnerEntity and bomb.SpawnerEntity:ToPlayer() ~= nil,
            owner = bomb.SpawnerEntity and GetPtrHash(bomb.SpawnerEntity) or nil,
            flags = bomb.Flags,
          })
        end
      end
    end
  end

  state.percepts.enemies = enemies
  state.percepts.projectiles = projectiles
  state.percepts.lasers = lasers
  state.percepts.creep = creep
  state.percepts.bombs = bombs
  state.percepts.pickups = pickups
end

local function scan_room_grid(state)
  local room = game:GetRoom()
  local grid = state.percepts.grid or {}
  grid = clear_array(grid)

  if room then
    local size = room:GetGridSize()
    for index = 0, size - 1 do
      local gridEntity = room:GetGridEntity(index)
      if gridEntity then
        grid[index + 1] = {
          index = index,
          type = gridEntity:GetType(),
          collision = gridEntity.CollisionClass,
        }
      end
    end
  end

  state.percepts.grid = grid
end

local function scan_doors(state)
  local room = game:GetRoom()
  local doors = state.percepts.doors or {}
  doors = clear_array(doors)
  if room then
    for slot = DoorSlot.LEFT0, DoorSlot.NUM_DOOR_SLOTS - 1 do
      local door = room:GetDoor(slot)
      if door then
        table.insert(doors, {
          slot = slot,
          exists = true,
          position = safe_vector(door.Position),
          open = door:IsOpen(),
          roomIdx = door.TargetRoomIndex,
          roomType = door.TargetRoomType,
        })
      end
    end
  end
  state.percepts.doors = doors
end

local function scan_map(state)
  local level = game:GetLevel()
  local rooms = level and level:GetRooms()
  local mapInfo = state.percepts.map or {}
  mapInfo.rooms = mapInfo.rooms or {}
  mapInfo.visited = mapInfo.visited or {}
  mapInfo.unvisited = mapInfo.unvisited or {}
  clear_array(mapInfo.rooms)
  clear_array(mapInfo.visited)
  clear_array(mapInfo.unvisited)

  if rooms then
    for i = 0, rooms.Size - 1 do
      local roomDesc = rooms:Get(i)
      if roomDesc then
        local data = {
          index = roomDesc.GridIndex,
          roomType = roomDesc.Data and roomDesc.Data.Type or RoomType.ROOM_DEFAULT,
          visited = roomDesc.Visited,
          clear = roomDesc.Clear,
          displayFlags = roomDesc.DisplayFlags,
        }
        table.insert(mapInfo.rooms, data)
        if roomDesc.Visited then
          table.insert(mapInfo.visited, data.index)
        else
          table.insert(mapInfo.unvisited, data.index)
        end
      end
    end
  end

  state.percepts.map = mapInfo
end

function Sense.init(state)
  state.percepts = state.percepts or {}
  state.percepts.enemies = state.percepts.enemies or {}
  state.percepts.projectiles = state.percepts.projectiles or {}
  state.percepts.lasers = state.percepts.lasers or {}
  state.percepts.creep = state.percepts.creep or {}
  state.percepts.bombs = state.percepts.bombs or {}
  state.percepts.pickups = state.percepts.pickups or {}
  state.percepts.grid = state.percepts.grid or {}
  state.percepts.doors = state.percepts.doors or {}
  state.percepts.map = state.percepts.map or { rooms = {}, visited = {}, unvisited = {} }
end

function Sense.update(state, player)
  capture_player_snapshot(state, player)
  gather_enemies(state, player)
  scan_room_grid(state)
  scan_doors(state)
  scan_map(state)
end

function Sense.has_los(fromPos, toPos, gridCollision)
  local room = game:GetRoom()
  if not room then
    return false
  end
  gridCollision = gridCollision or GridCollisionClass.COLLISION_NONE
  return room:CheckLine(fromPos, toPos, gridCollision)
end

function Sense.dist2(a, b)
  local dx = a.X - b.X
  local dy = a.Y - b.Y
  return dx * dx + dy * dy
end

function Sense.nearest(list, pos, filter)
  if not list or not pos then
    return nil, math.huge
  end

  local best = nil
  local bestDist = math.huge
  for _, entry in ipairs(list) do
    if not filter or filter(entry) then
      local dist = Sense.dist2(entry.position, pos)
      if dist < bestDist then
        best = entry
        bestDist = dist
      end
    end
  end

  return best, bestDist
end

return Sense
