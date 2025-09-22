--- Perception module.
-- Collects a snapshot of the current run state including player stats, room
-- entities, grid hazards, and floor metadata. Results are stored on the shared
-- blackboard under `state.percepts` and refreshed each frame.

local Sense = {}

local game = Game()

local ACTIVE_SLOT_PRIMARY = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
local ACTIVE_SLOT_POCKET = ActiveSlot and ActiveSlot.SLOT_POCKET or 0
local MAX_DOOR_SLOTS = DoorSlot and DoorSlot.NUM_DOOR_SLOTS or 8
local DEFAULT_WEAPON_TYPE = WeaponType and WeaponType.WEAPON_TEARS or 1
local DEFAULT_NO_DIRECTION = Direction and Direction.NO_DIRECTION or -1
local ZERO_VECTOR = Vector(0, 0)

local function vector_to_table(vec)
  if vec == nil then
    return { x = 0, y = 0 }
  end

  return { x = vec.X or 0, y = vec.Y or 0 }
end

local function color_to_table(color)
  if color == nil then
    return nil
  end

  return {
    r = color.R or 0,
    g = color.G or 0,
    b = color.B or 0,
    a = color.A or 0,
  }
end

local function compute_tears_per_second(player)
  if player == nil then
    return 0
  end

  local maxFireDelay = player.MaxFireDelay or 0
  if maxFireDelay < 0 then
    -- Charge-style weapons expose negative fire delay. Treat as 30 tears/s so
    -- DPS remains meaningful while other modules can handle charge timing.
    return 30
  end

  return 30 / (maxFireDelay + 1)
end

local function compute_dps(player)
  if player == nil then
    return 0
  end

  return (player.Damage or 0) * compute_tears_per_second(player)
end

local function capture_health(player)
  if player == nil then
    return {
      red = 0,
      max = 0,
      soul = 0,
      black = 0,
      bone = 0,
      rotten = 0,
      rottenBone = 0,
      golden = 0,
      eternal = 0,
    }
  end

  local redHearts = player.GetHearts and player:GetHearts() or 0
  local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or 0
  local blackHearts = player.GetBlackHearts and player:GetBlackHearts() or 0
  local boneHearts = player.GetBoneHearts and player:GetBoneHearts() or 0
  local rottenHearts = player.GetRottenHearts and player:GetRottenHearts() or 0
  local rottenBoneHearts = player.GetRottenBoneHearts and player:GetRottenBoneHearts() or 0
  local goldenHearts = player.GetGoldenHearts and player:GetGoldenHearts() or 0
  local eternalHearts = player.GetEternalHearts and player:GetEternalHearts() or 0
  local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or 0

  return {
    red = redHearts / 2,
    max = maxHearts / 2,
    soul = soulHearts / 2,
    black = blackHearts / 2,
    bone = boneHearts,
    rotten = rottenHearts,
    rottenBone = rottenBoneHearts,
    golden = goldenHearts,
    eternal = eternalHearts,
  }
end

local function capture_player(player)
  if player == nil then
    return nil
  end

  local moveInput = player.GetMovementInput and player:GetMovementInput() or ZERO_VECTOR
  local shootInput = player.GetShootingInput and player:GetShootingInput() or ZERO_VECTOR
  local playerPosition = vector_to_table(player.Position)

  local tearFlags = player.GetTearFlags and player:GetTearFlags() or 0
  local weaponType = player.GetWeaponType and player:GetWeaponType() or DEFAULT_WEAPON_TYPE
  local fireDirection = player.GetFireDirection and player:GetFireDirection() or DEFAULT_NO_DIRECTION
  local moveDirection = player.GetMovementDirection and player:GetMovementDirection() or DEFAULT_NO_DIRECTION

  return {
    index = player.ControllerIndex or 0,
    type = player:GetPlayerType(),
    name = player:GetName(),
    position = playerPosition,
    velocity = vector_to_table(player.Velocity),
    moveInput = vector_to_table(moveInput),
    shootInput = vector_to_table(shootInput),
    fireDirection = fireDirection,
    movementDirection = moveDirection,
    canFly = player.CanFly,
    fallSpeed = player.TearFallingSpeed or 0,
    fallAccel = player.TearFallingAcceleration or 0,
    tearHeight = player.TearHeight or 0,
    tearFlags = tearFlags,
    bombFlags = player.GetBombFlags and player:GetBombFlags() or 0,
    weaponType = weaponType,
    damage = player.Damage or 0,
    shotSpeed = player.ShotSpeed or 0,
    range = player.TearRange or 0,
    speed = player.MoveSpeed or 0,
    luck = player.Luck or 0,
    maxFireDelay = player.MaxFireDelay or 0,
    tearsPerSecond = compute_tears_per_second(player),
    dps = compute_dps(player),
    damageMultiplier = player.DamageMultiplier or 1,
    fireRateMultiplier = player.FireDelayMultiplier or 1,
    tearColor = color_to_table(player.TearColor),
    inventory = {
      bombs = player.GetNumBombs and player:GetNumBombs() or 0,
      keys = player.GetNumKeys and player:GetNumKeys() or 0,
      coins = player.GetNumCoins and player:GetNumCoins() or 0,
      activeItem = player.GetActiveItem and player:GetActiveItem(ACTIVE_SLOT_PRIMARY) or 0,
      activeCharge = player.GetActiveCharge and player:GetActiveCharge(ACTIVE_SLOT_PRIMARY) or 0,
      card = player.GetCard and player:GetCard(0) or 0,
      pill = player.GetPill and player:GetPill(0) or 0,
      pocketActive = player.GetActiveItem and player:GetActiveItem(ACTIVE_SLOT_POCKET) or 0,
      pocketCharge = player.GetActiveCharge and player:GetActiveCharge(ACTIVE_SLOT_POCKET) or 0,
    },
    hearts = capture_health(player),
    trinkets = {
      primary = player.GetTrinket and player:GetTrinket(0) or 0,
      secondary = player.GetTrinket and player:GetTrinket(1) or 0,
    },
  }
end

local function base_entity_snapshot(entity)
  return {
    ptr = GetPtrHash(entity),
    id = entity.InitSeed,
    type = entity.Type,
    variant = entity.Variant,
    subType = entity.SubType,
    position = vector_to_table(entity.Position),
    velocity = vector_to_table(entity.Velocity),
    size = entity.Size,
    collisionClass = entity.EntityCollisionClass,
    flags = entity:GetEntityFlags(),
  }
end

local function capture_enemy(entity, playerPosition)
  local npc = entity:ToNPC()
  if npc == nil then
    return nil
  end

  local snapshot = base_entity_snapshot(entity)
  snapshot.hitPoints = npc.HitPoints or 0
  snapshot.maxHitPoints = npc.MaxHitPoints or 0
  snapshot.state = npc.State
  snapshot.subState = npc.SubState
  snapshot.iFrames = npc:GetDamageCooldown()
  snapshot.isBoss = npc:IsBoss()
  snapshot.isChampion = npc:IsChampion()
  snapshot.collisionDamage = npc.CollisionDamage or 0
  snapshot.gridCollisionClass = npc.GridCollisionClass
  snapshot.entityCollisionClass = npc.EntityCollisionClass
  snapshot.targetPtr = npc.Target and GetPtrHash(npc.Target) or nil
  snapshot.distance = playerPosition and entity.Position:Distance(Vector(playerPosition.x, playerPosition.y)) or nil

  return snapshot
end

local function capture_projectile(entity)
  local projectile = entity:ToProjectile()
  if projectile == nil then
    return nil
  end

  local snapshot = base_entity_snapshot(entity)
  snapshot.height = projectile.Height
  snapshot.fallingSpeed = projectile.FallingSpeed
  snapshot.fallingAccel = projectile.FallingAccel
  snapshot.scale = projectile.Scale
  snapshot.flags = projectile.ProjectileFlags
  snapshot.damage = projectile.CollisionDamage

  return snapshot
end

local function capture_pickup(entity)
  local pickup = entity:ToPickup()
  if pickup == nil then
    return nil
  end

  local snapshot = base_entity_snapshot(entity)
  snapshot.price = pickup.Price or 0
  snapshot.wait = pickup.Wait or 0
  snapshot.subType = pickup.SubType
  snapshot.optionsPickupIndex = pickup.OptionsPickupIndex or 0
  snapshot.isShopItem = pickup:IsShopItem()
  snapshot.isLocked = pickup:IsLocked()

  return snapshot
end

local function capture_bomb(entity)
  local bomb = entity:ToBomb()
  if bomb == nil then
    return nil
  end

  local snapshot = base_entity_snapshot(entity)
  snapshot.explosionDamage = bomb.ExplosionDamage or 0
  snapshot.explosionCountdown = bomb.ExplosionCountdown or 0
  snapshot.radiusMultiplier = bomb.RadiusMultiplier or 1
  snapshot.isMega = bomb.IsMega or false
  snapshot.isPlayerOwned = bomb.IsPlayerBomb or false
  snapshot.variantFlags = bomb.Flags or 0
  snapshot.isSadBomb = bomb.IsSadBomb or false
  snapshot.isBurning = bomb.IsBurning or false

  return snapshot
end

local function capture_familiar(entity)
  local familiar = entity:ToFamiliar()
  if familiar == nil then
    return nil
  end

  local snapshot = base_entity_snapshot(entity)
  snapshot.orbitLayer = familiar.OrbitLayer or 0
  snapshot.fireCooldown = familiar.FireCooldown or 0
  snapshot.player = familiar.Player and GetPtrHash(familiar.Player) or nil

  return snapshot
end

local function capture_entities(playerSnapshot)
  local result = {
    enemies = {},
    projectiles = {},
    pickups = {},
    bombs = {},
    familiars = {},
    others = {},
    summary = {
      enemyCount = 0,
      bossCount = 0,
      championCount = 0,
      projectileCount = 0,
      pickupCount = 0,
      bombCount = 0,
      familiarCount = 0,
      otherCount = 0,
    },
  }

  local playerPosition = playerSnapshot and playerSnapshot.position or nil
  local roomEntities = Isaac and Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}
  for _, entity in ipairs(roomEntities) do
    if entity ~= nil and entity:Exists() then
      local npc = entity:ToNPC()
      if npc ~= nil and npc:IsEnemy() and not npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
        local enemySnapshot = capture_enemy(entity, playerPosition)
        if enemySnapshot ~= nil then
          table.insert(result.enemies, enemySnapshot)
          result.summary.enemyCount = result.summary.enemyCount + 1
          if enemySnapshot.isBoss then
            result.summary.bossCount = result.summary.bossCount + 1
          end
          if enemySnapshot.isChampion then
            result.summary.championCount = result.summary.championCount + 1
          end
        end
      elseif entity:ToProjectile() ~= nil then
        local projectileSnapshot = capture_projectile(entity)
        if projectileSnapshot ~= nil then
          table.insert(result.projectiles, projectileSnapshot)
          result.summary.projectileCount = result.summary.projectileCount + 1
        end
      elseif entity:ToPickup() ~= nil then
        local pickupSnapshot = capture_pickup(entity)
        if pickupSnapshot ~= nil then
          table.insert(result.pickups, pickupSnapshot)
          result.summary.pickupCount = result.summary.pickupCount + 1
        end
      elseif entity:ToBomb() ~= nil then
        local bombSnapshot = capture_bomb(entity)
        if bombSnapshot ~= nil then
          table.insert(result.bombs, bombSnapshot)
          result.summary.bombCount = result.summary.bombCount + 1
        end
      elseif entity:ToFamiliar() ~= nil then
        local familiarSnapshot = capture_familiar(entity)
        if familiarSnapshot ~= nil then
          table.insert(result.familiars, familiarSnapshot)
          result.summary.familiarCount = result.summary.familiarCount + 1
        end
      else
        local otherSnapshot = base_entity_snapshot(entity)
        table.insert(result.others, otherSnapshot)
        result.summary.otherCount = result.summary.otherCount + 1
      end
    end
  end

  return result
end

local gridHazardNames = {
  spikes = {
    "GRID_SPIKES",
    "GRID_SPIKES_ONOFF",
    "GRID_SPIKES_RANDOM",
    "GRID_SPIKES_TIMER",
  },
  pits = {
    "GRID_PIT",
    "GRID_PIT_SPIKES",
    "GRID_TRAPDOOR",
  },
  fires = {
    "GRID_FIREPLACE",
    "GRID_BURNING_FIREPLACE",
    "GRID_RED_FIREPLACE",
  },
  rocks = {
    "GRID_ROCK",
    "GRID_ROCK_BOMB",
    "GRID_ROCK_ALT",
    "GRID_ROCK_ALT2",
    "GRID_ROCK_GOLD",
    "GRID_ROCK_SUPERTNT",
    "GRID_ROCK_TINTED",
  },
  buttons = {
    "GRID_PRESSURE_PLATE",
    "GRID_TELEPORTER",
    "GRID_TRAPDOOR",
  },
  creep = {
    "GRID_POOP",
    "GRID_CREEP",
  },
}

local function add_to_group(groups, key, entry)
  groups[key] = groups[key] or {}
  table.insert(groups[key], entry)
end

local function build_grid_lookup()
  local lookup = {}
  if GridEntityType == nil then
    return lookup
  end

  for key, nameList in pairs(gridHazardNames) do
    lookup[key] = {}
    for _, name in ipairs(nameList) do
      local gridType = GridEntityType[name]
      if gridType ~= nil then
        lookup[key][gridType] = true
      end
    end
  end
  return lookup
end

local gridLookup = build_grid_lookup()

local function summarize_rooms(level)
  if level == nil or level.GetRooms == nil then
    return 0, 0, 0
  end

  local rooms = level:GetRooms()
  if rooms == nil or rooms.Size == nil then
    return 0, 0, 0
  end

  local totalRooms = rooms.Size
  local cleared = 0
  local visited = 0

  for index = 0, totalRooms - 1 do
    local roomDesc = rooms:Get(index)
    if roomDesc ~= nil then
      if roomDesc.Clear then
        cleared = cleared + 1
      end
      if roomDesc.VisitedCount ~= nil and roomDesc.VisitedCount > 0 then
        visited = visited + 1
      end
    end
  end

  return totalRooms, cleared, visited
end

local function capture_grid(room)
  if room == nil then
    return {
      hazards = {},
      blockers = {},
      doors = {},
      size = 0,
      shape = -1,
    }
  end

  local gridInfo = {
    hazards = {},
    blockers = {},
    doors = {},
    size = room:GetGridSize(),
    shape = room:GetRoomShape(),
    topLeft = vector_to_table(room:GetTopLeftPos()),
    bottomRight = vector_to_table(room:GetBottomRightPos()),
  }

  local gridSize = room:GetGridSize() or 0
  for index = 0, gridSize - 1 do
    local gridEntity = room:GetGridEntity(index)
    if gridEntity ~= nil then
      local entry = {
        index = index,
        type = gridEntity:GetType(),
        variant = gridEntity:GetVariant(),
        state = gridEntity.State or 0,
        position = vector_to_table(room:GetGridPosition(index)),
      }

      local added = false
      for groupKey, typeLookup in pairs(gridLookup) do
        if typeLookup[entry.type] then
          add_to_group(gridInfo.hazards, groupKey, entry)
          added = true
          break
        end
      end

      if not added then
        add_to_group(gridInfo.blockers, tostring(entry.type), entry)
      end
    end
  end

  for slot = 0, MAX_DOOR_SLOTS - 1 do
    local door = room:GetDoor(slot)
    if door ~= nil then
      table.insert(gridInfo.doors, {
        slot = slot,
        exists = true,
        targetRoomIndex = door.TargetRoomIndex,
        targetRoomType = door.TargetRoomType,
        variant = door.Variant,
        state = door.State,
        isOpen = door:IsOpen(),
        isLocked = door:IsLocked(),
        isRoomClearDoor = door:IsRoomClearDoor(),
        requiresKey = door:IsKeyDoor(),
      })
    end
  end

  return gridInfo
end

local function capture_room(room)
  if room == nil then
    return {
      type = -1,
      variant = -1,
      index = -1,
      danger = false,
      isClear = true,
      frameCount = 0,
      damageTaken = 0,
      enemyKillCount = 0,
      spawnSeed = 0,
    }
  end

  local descriptor = game:GetLevel() and game:GetLevel():GetCurrentRoomDesc()
  local roomIndex = descriptor and descriptor.SafeGridIndex or -1

  return {
    type = room:GetType(),
    variant = room:GetVariant(),
    stageID = descriptor and descriptor.Data and descriptor.Data.StageID or -1,
    index = roomIndex,
    danger = not room:IsClear(),
    isClear = room:IsClear(),
    frameCount = room:GetFrameCount(),
    damageTaken = room:GetDamageTaken(),
    enemyKillCount = room:GetAliveEnemiesCount(),
    spawnSeed = room:GetSpawnSeed(),
    clearRewarded = room:IsClearRewarded(),
  }
end

local function capture_floor(level)
  if level == nil then
    return {
      stage = -1,
      stageType = -1,
      absoluteStage = -1,
      stageSeed = 0,
      curseMask = 0,
      devilChance = 0,
      angelChance = 0,
      currentRoomIndex = -1,
      totalRooms = 0,
      roomsCleared = 0,
      roomsVisited = 0,
    }
  end

  local totalRooms, roomsCleared, roomsVisited = summarize_rooms(level)

  return {
    stage = level:GetStage(),
    stageType = level:GetStageType(),
    absoluteStage = level:GetAbsoluteStage(),
    stageSeed = level:GetStageSeed(),
    curseMask = level:GetCurses(),
    devilChance = level.GetDevilChance and level:GetDevilChance() or 0,
    angelChance = level.GetAngelChance and level:GetAngelChance() or 0,
    currentRoomIndex = level:GetCurrentRoomIndex(),
    totalRooms = totalRooms,
    roomsCleared = roomsCleared,
    roomsVisited = roomsVisited,
  }
end

function Sense.init(state)
  if state == nil then
    return
  end

  state.sense = state.sense or {
    lastFrame = -1,
  }
end

function Sense.update(state)
  if state == nil then
    return
  end

  state.percepts = state.percepts or {}
  state.sense = state.sense or {}

  local player = game and game:GetPlayer(0) or nil
  local room = game and game:GetRoom() or nil
  local level = game and game:GetLevel() or nil

  local playerSnapshot = capture_player(player)
  local entitiesSnapshot = capture_entities(playerSnapshot)
  local gridSnapshot = capture_grid(room)
  local roomSnapshot = capture_room(room)
  local floorSnapshot = capture_floor(level)

  state.percepts.player = playerSnapshot
  state.percepts.entities = entitiesSnapshot
  state.percepts.grid = gridSnapshot
  state.percepts.room = roomSnapshot
  state.percepts.floor = floorSnapshot
  state.percepts.updatedFrame = state.frame

  state.sense.lastFrame = state.frame
end

function Sense.debug(state)
  if state == nil or state.percepts == nil then
    return { "sense offline" }
  end

  local percepts = state.percepts
  local player = percepts.player or {}
  local entities = percepts.entities and percepts.entities.summary or {}
  local room = percepts.room or {}

  local lines = {}
  table.insert(lines, string.format("senseFrame=%s", tostring(percepts.updatedFrame)))
  table.insert(lines, string.format("playerDMG=%.2f tps=%.2f", player.damage or 0, player.tearsPerSecond or 0))
  table.insert(lines, string.format("enemies=%d projectiles=%d pickups=%d", entities.enemyCount or 0, entities.projectileCount or 0, entities.pickupCount or 0))
  table.insert(lines, string.format("roomType=%d clear=%s", room.type or -1, tostring(room.isClear)))

  return lines
end

return Sense
