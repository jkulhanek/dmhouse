"""Loads deepmind_lab.so."""

import imp
import pkg_resources
from dmhouse._dmhouse import DMHouseGoalEnv, DMHouseGoalNaturalEnv, generate_images  # noqa: F401

imp.load_dynamic(__name__, pkg_resources.resource_filename(
    __name__, 'deepmind_lab.so'))

import dmhouse
setattr(dmhouse, 'DMHouseGoalEnv', DMHouseGoalEnv)
setattr(dmhouse, 'DMHouseGoalNaturalEnv', DMHouseGoalNaturalEnv)
setattr(dmhouse, 'generate_images', generate_images)
