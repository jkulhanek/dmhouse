local make_map = require 'common.make_map'
local map_maker = require 'dmlab.system.map_maker'
local maze_generation = require 'dmlab.system.maze_generation'
local pickups = require 'common.pickups'
local hit_goal_decorator = require 'custom.hit_goal_decorator'
local observe_goal_decorator = require 'custom.observe_goal_decorator'
local custom_observations = require 'decorators.custom_observations'
local goal_distance_decorator = require 'custom.goal_distance_decorator'
local pickups_spawn = require 'dmlab.system.pickups_spawn'
local game = require 'dmlab.system.game'
local timeout = require 'decorators.timeout'
local random = require 'common.random'
local houseTs = require 'custom.house_theme'
local themes = require 'themes.themes'
local tuple = require 'common.tuple'

local factory = {}

local DEFAULT_MAP_ENTITIES = [[
*******
*C333P*
*0   2*
*0   2*
*0   2*
*0   2*
*C111C*
*******
]]

local CELL_SIZE = 64.0
local CEILING_HEIGHT = 2.2

local OBJECTS = {
  meuble_chevet = {
    width = CELL_SIZE * 0.7 / 32.0,
    depth = CELL_SIZE * 0.6 / 32.0,
    probabilityFactor = 1.0,
  },
  chair = {
    width = CELL_SIZE * 0.9 / 32.0,
    depth = CELL_SIZE * 0.9 / 32.0,
    probabilityFactor = 1.0,
  },
  chair2 = {
    width = CELL_SIZE * 0.9 / 32.0,
    depth = CELL_SIZE * 0.9 / 32.0,
    probabilityFactor = 1.0,
  },
  shoe_cabinet = {
    width = CELL_SIZE * 0.7 / 32.0,
    depth = CELL_SIZE * 0.6 / 32.0,
    probabilityFactor = 1.0,
  },
  coat_stand = {
    width = CELL_SIZE * 0.6 / 32.0,
    depth = CELL_SIZE * 0.6 / 32.0,
    probabilityFactor = 1.0,
  },
  cartboard_box = {
    width = CELL_SIZE * 0.7 / 32.0,
    depth = CELL_SIZE * 0.6 / 32.0,
    probabilityFactor = 1.0,
  },
  black_bookcase = {
    width = CELL_SIZE * 0.7 / 32.0,
    depth = CELL_SIZE * 0.6 / 32.0,
    probabilityFactor = 1.0,
  },
}

function factory.createLevelApi(kwargs)
  local api = {}
  local _kwargs = {
    negativeGoalReward = -1,
    positiveGoalReward = 0,
    finalGoalReward = 10,
    entityPercentage = 0.7,
    iterationsWithSameMap = 50 -- -1 for no repetitions
  }
  if kwargs ~= nil then
    for k,v in pairs(kwargs) do _kwargs[k] = v end
  end
  kwargs = _kwargs

  if kwargs['mapEntities'] == nil then
    kwargs['mapEntities'] = DEFAULT_MAP_ENTITIES
  end


  local objectSampleProbabilities = {}
  local totalPSum = 0.0
  for key, val in pairs(OBJECTS) do
    local pfactor = val.probabilityFactor or 1.0
    totalPSum = totalPSum + pfactor
    objectSampleProbabilities[#objectSampleProbabilities + 1] = {pfactor, key}
  end
  for i=1,#objectSampleProbabilities do
    objectSampleProbabilities[i][1] = objectSampleProbabilities[i][1] / totalPSum
  end

  function sampleObject(randomValue)
    local totalValue = 0.0
    for i=1,#objectSampleProbabilities do
      totalValue = totalValue + objectSampleProbabilities[i][1]
      if randomValue <= totalValue then
        return objectSampleProbabilities[i][2]
      end
    end
  end

  function api:_getEntityAlign(i, j, width, height)
    if i == 1 then
      return 3
    elseif i == width - 2 then
      return 1
    elseif j == 1 then
      return 0
    elseif j == height - 2 then
      return 2
    end

    print('Error: invalid align i: '..i..' j:'..j..' width:'..width..' height:'..height)
    return 1
  end

  local function applyOrientation(pos, object, orientation)
    local x = pos[1]
    local y = pos[2]
    if orientation == 0 then
      x = x - 0.5 + object.depth / CELL_SIZE / 2;
    elseif orientation == 1 then
      y = y - 0.5 + object.width / CELL_SIZE / 2;
    elseif orientation == 2 then
      x = x + 0.5 - object.depth / CELL_SIZE / 2;
    elseif orientation == 3 then
      y = y + 0.5 - object.width / CELL_SIZE / 2;
    end
    return {x, y, pos[3]}
  end

  function getOrientationVector(orientation)
    if orientation == 3 then
      return {0, -1, 0}
    elseif orientation == 1 then
      return {0, 1, 0}
    elseif orientation == 0 then
      return {1, 0, 0}
    elseif orientation == 2 then
      return {-1, 0, 0}
    end
  end

  function api:_getPhysicalPosition(i, j, width)
    x = j + 0.5;
    y = ((width or self._maze_width) - i - 1) + 0.5;
    return { x * CELL_SIZE, y * CELL_SIZE }
  end

  function api:_resetGoal()
    local finalGoalIndex = random:uniformInt(1, #self._currentEntities)
    local finalGoal = self._currentEntities[finalGoalIndex]
    for i, entity in ipairs(self._currentEntities) do
      entity.isCollected = nil
      if i == finalGoalIndex then
        entity.reward = kwargs.finalGoalReward
        entity.final = true
      elseif entity.type == finalGoal.type then
        entity.reward = kwargs.positiveGoalReward
        entity.final = false
      else
        entity.reward = kwargs.negativeGoalReward
        entity.final = false
      end
    end
  end

  function api:_generateEntitiesAndMaze()
    local maze = maze_generation.mazeGeneration{entity = kwargs['mapEntities']}
    local width, height = maze:size()
    local currentEntities = {}

    local entityLocations = {}
    local entityOrientations = {}
    local spawnLocations = {}

    for i = 1, (width - 2) do
      for j = 1, (height - 2) do
        local c = maze:getEntityCell(i + 1, j + 1)
        local orientation = tonumber(c)
        local isNearWall = orientation ~= nil
        local isCorner = c == "C" or c == "P"
        if not isCorner then
          if isNearWall then        
            entityLocations[#entityLocations + 1] = {i, j}
            entityOrientations[#entityLocations] = orientation
          elseif c ~= "*" then
            spawnLocations[#spawnLocations + 1] = {i, j}
          end
        end
      end
    end

    local entityCount = random:uniformInt(math.max(1, 
      math.floor(kwargs.entityPercentage * #entityLocations  - 3)),
      math.min(#entityLocations, math.floor(kwargs.entityPercentage * #entityLocations  + 3)))
    local placeGenerator = random:shuffledIndexGenerator(#entityLocations)

    local entities = {}
    local indexedEntities = {} 
    for i = 1,entityCount do
      local index = placeGenerator()
      local pos = entityLocations[index]
      local type = sampleObject(random:uniformReal(0, 1))
      local entity = {
        gridPos = pos,
        pos = self:_getPhysicalPosition(pos[1], pos[2], width),
        type = type,
        orientation = entityOrientations[index],
      }
      entity.truePos = applyOrientation(entity.pos, OBJECTS[entity.type], entity.orientation)
      entity.orientationVector = getOrientationVector(entity.orientation)
      entities[#entities + 1] = entity
      indexedEntities[tuple(entity.gridPos[1], entity.gridPos[2])] = entity
    end

    local i = placeGenerator()
    while i do
      spawnLocations[#spawnLocations + 1] = entityLocations[i]
      i = placeGenerator()
    end

    return {
      entities = entities,
      indexedEntities = indexedEntities,
      maze = maze,
      spawnLocations = spawnLocations,
    }
  end

  function api:_initializePickups(objects)
    self.pickups = {}
    for key, obj in pairs(objects) do
      self.pickups[key] = {
        name = key,
        classname = key,
        model = 'models/custom/'..key..'.md3',
        quantity = 1,
        type = pickups.type.REWARD,
        moveType = pickups.moveType.STATIC
      }
    end
  end

  function api:init(settings)
    if settings['same_map_episodes'] ~= nil then
        -- print('setting iterationsWithSameMap to ' .. settings['same_map_episodes'])
        kwargs['iterationsWithSameMap'] = tonumber(settings['same_map_episodes']) 
        io.flush()
    end
  end

  function api:_generateMap()
    self._iteration = self._iteration and (self._iteration + 1) or 1
    local generateNewMap = false
    if not self._map then
      generateNewMap = true
    elseif kwargs.iterationsWithSameMap > 0 and (self._iteration % kwargs.iterationsWithSameMap) == 1 then
      generateNewMap = true
    end

    if generateNewMap then
      local mapName = 'house_room_' .. self._seedParameter .. '_' .. self._iteration
      local theme = themes.fromTextureSet{
        textureSet = houseTs,
        decalFrequency = 0,
        floorModelFrequency = 0,
      }

      local entitiesResult = self:_generateEntitiesAndMaze()
      local width, height = entitiesResult.maze:size()
      map_maker:mapFromTextLevel{
        entityLayer = kwargs['mapEntities'],
        variationsLayer = nil,
        mapName = mapName,
        allowBots = false,
        skyboxTextureName = nil,
        theme = theme,
        cellSize = CELL_SIZE,
        ceilingScale = CEILING_HEIGHT,
        callback = function(i, j, c, maker)
          local entity = entitiesResult.indexedEntities[tuple(i, j)]
          if entity then
            local object = OBJECTS[entity.type]
            local e= maker:makePhysicalEntity{
               i = i,
               j = j,
               width = object.width,
               height = CEILING_HEIGHT * 2 * 100.0/32.0,
               depth = object.depth,
               align = entity.orientation,
               classname = entity.type,
            }
            return e         
          end
        end
      }

      self._currentEntities = entitiesResult.entities
      self._allSpawnLocations = entitiesResult.spawnLocations
      self._maze_width = width
      self._map = mapName
    end
  end

  function api:start(episode, seed, params)
    self._seedParameter = seed
    self:_initializePickups(OBJECTS)
    random:seed(seed)
      
    self:_generateMap()
  end

  function api:hasEpisodeFinished(timeSeconds)
    return false
  end

  function api:calculateBonus(goalId)
    if self._currentEntities[goalId].isCollected then
      return 0.0
    else
      self._currentEntities[goalId].isCollected = true
      return self._currentEntities[goalId].reward
    end
  end

  function api:updateGoals(entities, spawnLocation)
  end

  function api:nextMap()
    self:_generateMap()
    local spawnLocation = api._allSpawnLocations[
                                   random:uniformInt(1, #api._allSpawnLocations)]
    spawnLocation = self:_getPhysicalPosition(spawnLocation[1], spawnLocation[2])
    self._newSpawnVarsPlayerStart = {
      classname = 'info_player_start',
      origin = '' .. spawnLocation[1] .. ' ' .. spawnLocation[2] .. ' 30',
      angle = '' .. (90 * random:uniformInt(0, 3))
    }
    self._spawnLocation = spawnLocation

    -- Select new goal
    self:_resetGoal()
    self:updateGoals(self._currentEntities, spawnLocation)
    return self._map
  end


  function api:updateSpawnVars(spawnVars)
    if spawnVars.classname == "info_player_start" then
      return self._newSpawnVarsPlayerStart
    end

    if self.pickups[spawnVars.classname] then
      spawnVars.id = "1"
      spawnVars.spawnflags = "1"
    end

    if (self.pickups[spawnVars.classname] and self.pickups[spawnVars.classname:sub(0, -6)]) then
      -- is goal
      spawnVars.id = "2"
      spawnVars.spawnflags = "1"
    end
    return spawnVars
  end

  function api:canPickup(id, playerId)
      if id == 1 then
          return false
      end
      return true
  end

  -- Create apple explicitly
  function api:createPickup(classname)
    if (classname:len() > 5 and self.pickups[classname:sub(0, -6)]) then
        -- is goal
        local goalPickup = {}
        for key, value in pairs(self.pickups[classname:sub(0, -6)]) do
            goalPickup[key] = value
        end
        
        --update goal pickup
        goalPickup.type = pickups.type.GOAL
        return goalPickup
    end
    return self.pickups[classname]
  end

  return api
end

factory.CELL_SIZE = CELL_SIZE

return factory
