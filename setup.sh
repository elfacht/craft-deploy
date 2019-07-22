#!/bin/bash
#
# Initial setup
#
# @author
#   Martin Szymanski <martin@elfacht.com>
#   https://www.elfacht.com
#   https://github.com/elfacht
#
# @license MIT

### Check if releases folder exists
if [ ! -d "./releases/" ]
then
  printf -- "Create releases folder. \n"
  mkdir releases
fi

if [ ! -d "./shared/" ]
then
  printf -- "Create shared folder. \n"
  mkdir shared && cd "$_"
  mkdir web
fi

if [ ! -f "./deploy.log" ]
then
  printf -- "Create empty log file. \n"
  touch deploy.log
fi

if [ ! -f "./.env.example" ]
then
  printf -- "Rename .env.example. \n"
  mv .env.example .env
fi
