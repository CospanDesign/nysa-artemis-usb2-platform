#! /usr/bin/python

import site
import os
import sys
import json
import datetime

PATH_NAME = "paths.json"
BOARD_NAME = "artemis_usb2"
SITE_NYSA = os.path.join(site.getuserbase(), "nysa")
SITE_PATH = os.path.join(SITE_NYSA, PATH_NAME)
PLATFORM_PATH = os.path.abspath(os.path.dirname(__file__))
CONFIG_PATH = os.path.join(PLATFORM_PATH, BOARD_NAME, "board", "config.json")

if __name__ == "__main__":
    f = open(CONFIG_PATH, "r")
    config_dict = json.load(f)
    f.close()

    name = config_dict["board_name"].lower()
    now = datetime.datetime.now()
    #timestamp = now.strftime("%m/%d/%Y %X")
    timestamp = now.strftime("%x %X")

    #print "board name: %s" % name
    #print "Timestamp: %s" % timestamp
    #print "Base directory: %s" % PLATFORM_PATH
    #print "Path directory: %s" % SITE_PATH

    try:
        f = open(SITE_PATH, "r")
        path_dict = json.load(f)
        f.close()
    except IOError as e:
        print "site directories are not created, install Nysa before installing the board package"
        sys.exit(1)

    path_dict["boards"][name] = {}
    path_dict["boards"][name]["path"] = PLATFORM_PATH
    path_dict["boards"][name]["timestamp"] =timestamp

    f = open(SITE_PATH, "w")
    f.write(json.dumps(path_dict, sort_keys = True, indent = 2, separators=(",", ": ")))
    f.close()

