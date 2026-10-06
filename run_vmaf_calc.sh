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

		mkdir -p ./out/vmaf/${codec}/${res_}/${crf}/

		
		nohup ffmpeg-quality-metrics ./out/mp4/${codec}/${res_}/${crf}/${filename}_${res_}p_crf${crf}_${codec}.mp4  $file  --metrics psnr vmaf ssim --vmaf-model-params enable_transform=true -o ./out/vmaf/${codec}/${res_}/${crf}/${filename}_${res_}p_crf${crf}_${codec}.csv -of csv &
	    done
	done

    fi
done
