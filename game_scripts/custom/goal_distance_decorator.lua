local game = require 'dmlab.system.game'
local tensor = require 'dmlab.system.tensor'

local function decorator(api, kwargs)
    local position = nil
    local distance = 0
    local shortestDistance = 0

    local customObservation = api.customObservation
    function api:customObservation(name)
        if name == 'DISTANCE' then
            return tensor.Tensor{distance}
        elseif name == 'SHORTEST_DISTANCE' then
            return tensor.Tensor{shortestDistance}
        end
        return customObservation and customObservation(self, name) or nil
    end

    local customObservationSpec = api.customObservationSpec
    function api:customObservationSpec()
        local specs = customObservationSpec and customObservationSpec(self) or {}
        specs[#specs + 1] = {name = 'DISTANCE', type = 'Doubles', shape = {1}}
        specs[#specs + 1] = {name = 'SHORTEST_DISTANCE', type = 'Doubles', shape = {1}}
        return specs
    end

    local modifyControl = api.modifyControl
    function api:modifyControl(actions)
        npos = game:playerInfo().eyePos
        if position ~= nil then
            distance = distance + math.sqrt((position[1] - npos[1]) ^ 2 + (position[2] - npos[2]) ^ 2)
        end
        position = npos
        return modifyControl and modifyControl(self, actions) or actions
    end

    local updateGoals = api.updateGoals
    function api:updateGoals(goals, spawn)
        for i,goal in ipairs(goals) do
            if goal.final then
                shortestDistance = math.sqrt((goal.truePos[1] - spawn[1]) ^ 2 + (goal.truePos[2] - spawn[2]) ^ 2)
                break
            end
        end
        distance = 0
        return updateGoals and updateGoals(self, goals, spawn) or nil
    end
end

return decorator