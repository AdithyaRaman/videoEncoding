#!/bin/bash

for file in ~/concat_videos_v2/*; do
    
    base_name=$(basename "${file}" .mp4)
    echo $base_name $file

    #ffmpeg -i $file -f yuv4mpegpipe - | vca --y4m --input stdin --complexity-csv ./complexity_out/${base_name}.csv
    start_time=$(date +%s%3N)

    ./run_crf_hd.sh $file vp9
    sleep 5
    ./run_crf_hd.sh $file av1
    sleep 5
    ./run_crf_hd.sh $file h264
    sleep 5
    end_time_HD=$(date +%s%3N)
    elapsed_HD=$((end_time_HD - start_time))
    echo "$basename\t:\tExecution time HD: $elapsed_HD ms"


    ./run_crf_sd.sh $file vp9
    sleep 5
    ./run_crf_sd.sh $file av1
    sleep 5
    ./run_crf_sd.sh $file h264
    sleep 5
    end_time_SD=$(date +%s%3N)
    elapsed_SD=$((end_time_SD - end_time_HD))
    echo "$basename\t:\tExecution time SD: $elapsed_SD ms"
    
    
    ./run_crf_qhd.sh $file vp9
    sleep 5
    ./run_crf_qhd.sh $file av1
    sleep 5
    end_time_QHD=$(date +%s%3N)
    elapsed_QHD=$((end_time_QHD - end_time_SD))
    echo "$basename\t:\tExecution time QHD: $elapsed_QHD ms"
    # ./run_crf_qhd.sh $file h264
    # sleep 10


    ./run_crf_full.sh $file vp9
    sleep 5
    ./run_crf_full.sh $file av1
    sleep 5
    ./run_crf_full.sh $file h264
    sleep 5
    end_time_FULL=$(date +%s%3N)
    elapsed_FULL=$((end_time_FULL - end_time_QHD))
    echo "$basename\t:\tExecution time FULL: $elapsed_FULL ms"

    elapsed_COMPLETE=$((end_time_FULL - start_time))
    echo "$basename\t:\tExecution time COMPLETE: $elapsed_COMPLETE ms"
    
done

