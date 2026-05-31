#!/bin/bash

VIDEO=$1


./run_encoding_trials.sh $1 h264
sleep 30
./create_mp4_file.sh $1 h264
echo "Completed H.264"

./run_encoding_trials.sh $1 h265
sleep 30
./create_mp4_file.sh $1 h265
echo "Completed H.265"

./run_encoding_trials.sh $1 vp9
sleep 30
./create_mp4_file.sh $1 vp9
echo "Completed VP9"

./run_encoding_trials.sh $1 av1
sleep 30
./create_mp4_file.sh $1 av1
echo "Completed AV1"
