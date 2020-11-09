local hit_goal_decorator = require 'custom.hit_goal_decorator'
local observe_goal_decorator = require 'custom.observe_goal_decorator'
local goal_distance_decorator = require 'custom.goal_distance_decorator'
local timeout = require 'decorators.timeout'
local houseFactory = require 'custom.house_factory'

api = houseFactory.createLevelApi()

--timeout.decorate(api, 60 * 60)
--custom_observations.decorate(api)
hit_goal_decorator(api, {
  cellSize = houseFactory.CELL_SIZE,
})
observe_goal_decorator(api, {
  cellSize = houseFactory.CELL_SIZE,
})
goal_distance_decorator(api)
return api
