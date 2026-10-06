#!/bin/bash
res_list=("2560:1440" "1920:1080" "1280:720" "854:480" "640:360" "426:240" "256:144")

crf_list_h264=(30 24 18) # H264
crf_list_av1=(49 42 35) # AV1
crf_list_vp9=(49 42 35) # VP9

codec=$1

for file in ~/inter4k_composite/60fps/*.mp4;do
    if [ -f "$file" ];then
	filename=$(basename "$file")
	filename="${filename%.mp4}"

	for crf in "${crf_list_h264[@]}"; do
	    for res in "${res_list[@]}"; do
		res_="${res#*:}"

		echo $filename $res_ $crf

		mkdir -p ./out/xpsnr/${codec}/${res_}/${crf}/

		#$file = ./out/mp4/${codec}/1440/18/${filename}_1440p_crf18_libx264.mp4
		
		nohup ffmpeg -r 60 -i $file -r 60 -i ./out/mp4/${codec}/$res_/$crf/${filename}_${res_}p_crf${crf}_${codec}.mp4 -lavfi "[1:v]scale=3840:2160[scaled];[0:v][scaled]xpsnr=stats_file=./out/xpsnr/${codec}/${res_}/${crf}/${filename}_${res_}p_crf${crf}_${codec}.csv" -f null - &
		
	    done
	done

    fi
done
