local hit_goal_decorator = require 'custom.hit_goal_decorator'
local observe_goal_decorator = require 'custom.observe_goal_decorator'
local goal_distance_decorator = require 'custom.goal_distance_decorator'
local game = require 'dmlab.system.game'
local timeout = require 'decorators.timeout'
local houseFactory = require 'custom.house_factory'

function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

api = houseFactory.createLevelApi()
local buttonsDown = 0
local poses = nil
local pose_index = 0 

local init = api.init
function api:init(settings)
  poses = split(settings['poses'], ',')
  --return init and init(settings)
end

local modifyControl = api.modifyControl
function api:modifyControl(actions)
  if actions.moveBackForward > 0 then
    pose_index = pose_index + 1
    print('rendering view '..pose_index)
    pose = split(poses[pose_index], '%s')
    game:console('setviewpos '..pose[1] .. ' ' .. pose[2] .. ' 30 '.. pose[3])
  end
  actions.buttonsDown = 0
  actions.moveBackForward = 0
  actions.strafeLeftRight = 0
  actions.crouchJump = 0
  return modifyControl and modifyControl(self, actions) or actions
end
return api
