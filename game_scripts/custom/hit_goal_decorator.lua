local game = require 'dmlab.system.game'

local function computeDistanceAndAngle(playerInfo, goal)
  local distance = 
    math.sqrt((playerInfo.eyePos[1] - goal[1]) ^ 2 +
      (playerInfo.eyePos[2] - goal[2]) ^ 2);

  local goalAngle = math.asin((goal[1] - playerInfo.eyePos[1]) / distance) * 180 / math.pi
  if playerInfo.eyePos[2] - goal[2] < 0 then
    goalAngle = 180 - goalAngle
  end
  goalAngle = goalAngle - 90
  local angleDiff = (goalAngle - playerInfo.angles[2]) % 360
  if angleDiff > 180 then
    angleDiff = 360 - angleDiff
  end

  return {distance, angleDiff}
end

local function isHittingGoal(playerInfo, goal, kwargs)
  local distanceSquared = 
    (playerInfo.eyePos[1] - goal[1]) ^ 2 +
      (playerInfo.eyePos[2] - goal[2]) ^ 2

  goal[3] = playerInfo.eyePos[3]
  local inFov = game:inFov(playerInfo.eyePos, goal, playerInfo.angles, 60)
  return inFov and distanceSquared < (kwargs.maxDistance * kwargs.cellSize) ^ 2
end


local function decorator(api, kwargs)
  local hittingGoal = false
  local currentGoals = {}
  local config = {
    maxDistance = kwargs.maxDistance or 0.7,
    cellSize = kwargs.cellSize,
    maxAngle = kwargs.maxAngle or 60,
  }

  if not api.calculateBonus then
    function api:calculateBonus(goalId)
      return 1.0
    end
  end

  local modifyControl = api.modifyControl
  function api:modifyControl(actions)
    if actions.crouchJump > 0 then
      actions.crouchJump = 0
      if not hittingGoal then
        local maxScore = nil
        local isFinal = false
        for i,goal in ipairs(currentGoals) do
          if isHittingGoal(game:playerInfo(), goal.truePos, config) then
            maxScore = maxScore and math.max(maxScore, api:calculateBonus(i)) or api:calculateBonus(i)
            if goal.final then
              isFinal = true
            end
          end
        end
        if maxScore and maxScore ~= 0 then
          game:addScore(maxScore)
        end
        if isFinal then
          self._goalReached = 2
        end
        hittingGoal = true
      end
    else
      hittingGoal = false
    end
    return modifyControl and modifyControl(self, actions) or actions
  end

  local updateGoals = api.updateGoals
  function api:updateGoals(goals, spawn)
    currentGoals = goals
    return updateGoals and updateGoals(self, goals, spawn) or nil
  end

  local nextMap = api.nextMap
  function api:nextMap()
    self._goalReached = nil
    return nextMap(self)
  end

  local hasEpisodeFinished = api.hasEpisodeFinished
  function api:hasEpisodeFinished(timeSeconds)
    local finish = false
    if self._goalReached and self._goalReached > 0 then
      self._goalReached = self._goalReached - 1
    elseif self._goalReached == 0 then
      finish = true
    end
    return finish or (hasEpisodeFinished and hasEpisodeFinished(api, timeSeconds) or false)
  end
end

return decorator
