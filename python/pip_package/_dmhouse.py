import gym
import numpy as np


def _action(*entries):
    return np.array(entries, dtype=np.intc)


ACTION_LIST = [
    _action(0,   0,  0,  1, 0, 0, 0),  # forward
    _action(0,   0,  0, -1, 0, 0, 0),  # backward
    _action(-20,   0,  0,  0, 0, 0, 0),  # look_left
    _action(20,   0,  0,  0, 0, 0, 0),  # look_right
    # _action(  0,   0, -1,  0, 0, 0, 0), # strafe_left
    # _action(  0,   0,  1,  0, 0, 0, 0), # strafe_right
    _action(0,   0,  0,  0, 0, 1, 0),  # collect object
]


class DMHouseGoalEnv(gym.Env):
    metadata = {'render.modes': ['rgb_array']}

    def __init__(self, screen_size=(84, 84), renderer="hardware", same_map_episodes=50, steps_repeat=1, level=None, distance_scale=1, **kwargs):
        import dmhouse

        if level is None:
            level = 'custom/house'

        super().__init__(**kwargs)
        height, width = screen_size

        self._distance_scale = distance_scale
        self._colors = ['RGBD_INTERLEAVED', 'GOAL_RGB_INTERLEAVED', 'DISTANCE', 'SHORTEST_DISTANCE']
        self._lab = dmhouse.Lab(level, self._colors,
                                dict(fps=str(60), width=str(width), height=str(height), same_map_episodes=str(same_map_episodes)),
                                renderer=renderer)

        self.action_space = gym.spaces.Box(low=-np.inf, high=np.inf, shape=(7,), dtype=np.intc)
        self.observation_space = gym.spaces.Tuple((
            gym.spaces.Box(0, 255, (height, width, 3), dtype=np.uint8),
            gym.spaces.Box(0, 225, (height, width, 3), dtype=np.uint8),
            gym.spaces.Box(0, 225, (height, width, 1), dtype=np.uint8)))

        self._steps_repeat = steps_repeat
        self._last_observation = None
        self._distance = None
        self._shortestDistance = None

    def step(self, action):
        reward = self._lab.step(action, num_steps=self._steps_repeat) / 10.0
        terminal = not self._lab.is_running()
        obs = None if terminal else self.observe(self._lab.observations())
        self._last_observation = obs if obs is not None else tuple([np.copy(x) for x in list(self._last_observation)])
        return self._last_observation, reward, terminal, dict(distance=self._distance, shortest_distance=self._shortestDistance)

    def metrics(self):
        return (self._distance, self._shortestDistance)

    def observe(self, obs):
        self._distance = obs['DISTANCE'] * self._distance_scale
        self._shortestDistance = obs['SHORTEST_DISTANCE'] * self._distance_scale
        return (
            obs[self._colors[0]][:, :, :3],
            obs[self._colors[1]],
            obs[self._colors[0]][:, :, 3:4]
        )

    def reset(self):
        self._distance = None
        self._shortestDistance = None
        self._lab.reset()
        self._last_observation = self.observe(self._lab.observations())
        return self._last_observation

    def seed(self, seed=None):
        self._lab.reset(seed=seed)

    def close(self):
        lab = self._lab
        self._lab = None
        if lab is not None:
            lab.close()

    def render(self, mode='rgb_array', close=False):
        if mode == 'rgb_array':
            return self._lab.observations()['RGBD_INTERLEAVED'][:, :, :3]
        else:
            super().render(mode=mode)  # just raise an exception

    def __del__(self):
        self.close()


def generate_images(seed, poses, screen_size=(84, 84), renderer='hardware'):
    import dmhouse

    height, width = screen_size
    poses_str = ','.join('{} {} {}'.format(*x) for x in poses)
    lab = dmhouse.Lab('custom/house_renderer', ['RGBD_INTERLEAVED'],
                      dict(fps=str(60), width=str(width), height=str(height), poses=poses_str),
                      renderer=renderer)
    lab.reset(seed=seed)

    i = 0
    for _ in poses:
        lab.step(_action(0, 0, 0, 1, 0, 0, 0), num_steps=1)
        lab.step(_action(0, 0, 0, 0, 0, 0, 0), num_steps=7)
        obs = lab.observations()
        i += 1
        yield (obs['RGBD_INTERLEAVED'][:, :, :3], obs['RGBD_INTERLEAVED'][:, :, 3:4])
    lab.close()
    if i < len(poses):
        raise RuntimeError(f'There was an error when generating images, the number of generated images ({i}) is not equal to the number of requested images ({len(poses)})')


class NaturalActionWrapper(gym.ActionWrapper):
    def __init__(self, env):
        super().__init__(env)
        self.action_space = gym.spaces.Discrete(len(ACTION_LIST))

    def action(self, action):
        return ACTION_LIST[action]


def DMHouseGoalNaturalEnv(*args, steps_repeat=4, **kwargs):
    env = DMHouseGoalEnv(*args, steps_repeat=steps_repeat, **kwargs)
    env = NaturalActionWrapper(env)
    return env


# Register environments
gym.register(
    id='DMHouse-v1',
    entry_point='dmhouse:DMHouseGoalNaturalEnv',
)

gym.register(
    id='DMHouseOriginal-v1',
    entry_point='dmhouse:DMHouseGoalEnv',
)