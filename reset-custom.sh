#!/usr/bin/env bash

echo 'start with left settings_reset-custom'
sleep 20
./flash.sh ./output/settings_reset-custom.uf2

echo 'now switch to right'
sleep 20
./flash.sh ./output/settings_reset-custom.uf2

