#!/bin/bash
#
# Craft CMS deployment script on staging/production servers.
#
# @author
#   Martin Szymanski <martin@elfacht.com>
#   https://www.elfacht.com
#   https://github.com/elfacht
#
# @license MIT

if [ -d "./current/" ]
then
  php current/craft migrate/all
  php current/craft project-config/sync
fi

