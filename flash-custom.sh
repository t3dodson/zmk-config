#!/usr/bin/env bash

echo 'start with left custom'
sleep 20
./flash.sh ./output/left-custom.uf2

echo 'now switch to right'
sleep 20
./flash.sh ./output/right-custom.uf2

