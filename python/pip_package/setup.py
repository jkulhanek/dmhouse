"""Setup for the deepmind_lab module."""

import setuptools
import os

REQUIRED_PACKAGES = [
    'numpy==1.19.5',
    'six >= 1.10.0',
    'gym'
]

HERE = os.path.dirname(os.path.abspath(__file__))
README = open(os.path.join(HERE, "README.md"), 'r').read() + '\n'
LICENSE = open(os.path.join(HERE, "LICENSE"), 'r').read()
from _version import __version__

setuptools.setup(
    name='dmhouse',
    version=__version__,
    long_description=README,
    long_description_content_type="text/markdown",
    description='DMHouse 3D environment simulator',
    url='https://github.com/jkulhanek/dmlab-vn',
    classifiers=[
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
    ],
    license='MIT',
    author='Jonas Kulhanek',
    author_email='jonas.kulhanek@live.com',
    packages=setuptools.find_packages(),
    install_requires=REQUIRED_PACKAGES,
    include_package_data=True)
