#! /usr/bin/env python

import os
import glob

from setuptools import setup, find_packages
from distutils.command.install import install as DistutilsInstall

long_desc=open("README.md").read(),

try:
    #Try and convert the readme from markdown to pandoc
    from pypandoc import convert
    long_desc = convert("README.md", 'rst')
except:
    pass

setup( 
    name='nysa-artemis-usb2-platform',
    version='0.0.1',
    description='Artemis USB 2.0 Platform for Nysa',
    author='Cospan Design',
    author_email='dave.mccoy@cospandesign.com',
    packages=find_packages('.'),
    url="http://artemis.cospandesign.com",
    package_data={'' : ["*.json", "*.png", "*.ucf", "*.rules"]},
    requires=['pyusb (>= 1.0.0b1)',
              'pyserial (>= 2.6)'],
    install_requires=['nysa',
                      'pyusb>=1.0.0b1',
                      'pyserial>=2.6'

    ],
    include_package_data = True,
    long_description=long_desc,
    classifiers=[
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "License :: OSI Approved :: MIT License",
        "Environment :: Console",
        "Programming Language :: Python :: 2.7",
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "Intended Audience :: Developers",
        "Intended Audience :: Education",
    ],
    keywords="FPGA",
    license="GPL"
)
