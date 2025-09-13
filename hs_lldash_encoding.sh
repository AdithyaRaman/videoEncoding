#!/bin/bash


# 1: input video file
# 2: resolution
# 3: resP

# declare -a bitrates_240p=(108 180)
# declare -a bitrates_360p=(273 375 450 562 675)
# declare -a bitrates_480p=(825 900 1050)
# declare -a bitrates_720p=(1200 1350 1500 1687 1875 2250 2400 2550 2812)
# declare -a bitrates_1080p=(3000 3225 3375 3750 4125 4500 4875 5250)
# declare -a bitrates_2k=(9000 11250 13500)

res_id="$1"
res="$2"
shift
shift
bitrates=("$@")

echo $res_id
echo $res

for b in "${bitrates[@]}";
do
    echo $b
    
    nohup ../raplPowerLogger/raplPowerLogger ./m31_encoding_power/m31_${res_id}_${b}k_vp91.csv > nohup.out &
    PID=$!
    sleep 10

    ffmpeg -i ./m31_2k_h264_60.mp4 \
	   -usage realtime \
	   -cpu-used 8 \
	   -speed 7 \
	   -vf scale=${res} \
	   -c:v libvpx-vp9 \
	   -b:v ${b}k  \
	   -preset veryfast \
	   -g 60 \
	   -keyint_min 60 \
	   -sc_threshold 0 \
	   -f dash \
	   -seg_duration 1 \
	   -frag_duration 0.2 \
	   -ldash 1 \
	   -use_template 1 \
	   -use_timeline 0 \
	   -init_seg_name "init_\$RepresentationID\$.\$ext\$" \
	   -media_seg_name "chunk_\$RepresentationID\$_\$Number%05d\$.\$ext\$" \
	   -adaptation_sets "id=0,streams=v" \
	   -remove_at_exit 0 \
	   ./ll_encoded_videos/manifest.mpd

    sleep 10
    kill -SIGTERM $PID
    wait $PID

    rm ll_encoded_videos/*
done
