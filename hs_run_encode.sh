#!/bin/bash

declare -a bitrates_240p=(101 168)
declare -a bitrates_360p=(255 350 420 525 630)
declare -a bitrates_480p=(770 840 979)
declare -a bitrates_720p=(1575 1750 2100 2240 2380 2625)
declare -a bitrates_1080p=(2800 3010 3150 3500 3849 4200 4550 4900)
declare -a bitrates_2k=(8400 10500 12600)


./hs_lldash_encoding.sh "240" "320:240" "${bitrates_240p[@]}"
./hs_lldash_encoding.sh "360p" "640:360" "${bitrates_360p[@]}"
./hs_lldash_encoding.sh "480p" "640:480" "${bitrates_480p[@]}"
./hs_lldash_encoding.sh "720p" "1280:720" "${bitrates_720p[@]}"
./hs_lldash_encoding.sh "1080p" "1920:1080" "${bitrates_1080p[@]}"
./hs_lldash_encoding.sh "2k" "2560:1440" "${bitrates_2k[@]}"
