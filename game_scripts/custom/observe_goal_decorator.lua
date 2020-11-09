local game = require 'dmlab.system.game'
local random = require 'common.random'

local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

local SCREEN_SHAPE = game:screenShape().buffer

local function computeFinalPositionAndOrientation(goals, kwargs)
    local finalGoal
    local cellSize = kwargs.cellSize
    local playerHeight = kwargs.playerHeight or 52
    for i, goal in ipairs(goals) do
        if goal.final then
            finalGoal = goal
            break
        end
    end

    -- Has final goal
    -- Find optimal position
    local pos = {0, 0, playerHeight}
    local randomRange = cellSize / 2 - 30
    local finalOrientationVector = {}
    for i = 1,2 do
        pos[i] = finalGoal.pos[i] + finalGoal.orientationVector[i] * cellSize + random:uniformInt(0, 2 * randomRange) - randomRange
        finalOrientationVector[i] = finalGoal.pos[i] - pos[i]
    end

    local angle = math.deg(math.atan2(finalOrientationVector[2], finalOrientationVector[1]))
    return {pos, {0, angle, 0}}
end

local function decorator(api, kwargs)
    local renderedScreen = nil
    local goalPosAndAngles
    local function goalInterleavedView()
        if renderedScreen then
            return renderedScreen
        end

        local buffer = game:renderCustomView{
            width = SCREEN_SHAPE.width,
            height = SCREEN_SHAPE.height,
            pos = goalPosAndAngles[1],
            look = goalPosAndAngles[2],
            renderPlayer = false,
        }

        renderedScreen = buffer
        return buffer
    end

    local obsSpec = {
        {
            name = "GOAL_RGB_INTERLEAVED", 
            type = "Bytes", 
            shape = {SCREEN_SHAPE.height, SCREEN_SHAPE.width, 3},
        },
    }

    local obs = {
        ['GOAL_RGB_INTERLEAVED'] = goalInterleavedView,
    }

    local updateGoals = api.updateGoals
    function api:updateGoals(goals, spawn)
        currentGoals = goals
        goalPosAndAngles = computeFinalPositionAndOrientation(goals, kwargs)
        return updateGoals and updateGoals(self, goals, spawn) or nil
    end

    local nextMap = api.nextMap
    function api:nextMap()
        renderedScreen = nil
        return nextMap(self)
    end

    local customObservationSpec = api.customObservationSpec
    function api:customObservationSpec()
        local specs = customObservationSpec and customObservationSpec(self) or {}
        for i, spec in ipairs(obsSpec) do
            specs[#specs + 1] = spec
        end
        return specs
    end

    local customObservation = api.customObservation
    function api:customObservation(name)
        return obs[name] and obs[name]() or customObservation(api, name)
    end
end

return decorator