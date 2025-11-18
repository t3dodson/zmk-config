#!/usr/bin/env bash

echo 'start with left travel'
sleep 20
./flash.sh ./output/left-travel.uf2

echo 'now switch to right'
sleep 20
./flash.sh ./output/right-travel.uf2

