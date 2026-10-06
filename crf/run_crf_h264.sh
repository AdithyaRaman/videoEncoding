#!/bin/bash

res_list=("2560:1440" "1920:1080" "1280:720" "854:480" "640:360" "426:240" "256:144")


crf_list=(30 24 18) # H264
#crf_list=(49 42 35) # AV1
#crf_list=(49 42 35) # VP9


for file in ~/inter4k_composite/60fps/*.mp4;do    
    if [ -f "$file" ];then
	filename=$(basename "$file")
	filename="${filename%.mp4}"

	#echo $filename

	for res in "${res_list[@]}"; do
	    for crf in "${crf_list[@]}"; do


		start_time=$(date +%s%3N)
		
		echo $filename "${res#*:}" $crf
		res_="${res#*:}"

		mkdir -p ./out/mp4/h264/${res_}/${crf}/
		sleep 5
		
		nohup /home/cc/bin/cham_monitor ./out/mp4/h264/${res_}/${crf}/${filename}_${res_}p_crf${crf}_h264.csv > sigh0.out &
		PID1=$!
		sleep 5r
		
		ffmpeg -i $file -vf scale=${res} -c:v libx264 -tune zerolatency -preset veryfast -crf $crf ./out/mp4/h264/${res_}/${crf}/${filename}_${res_}p_crf${crf}_h264.mp4

		sleep 5
		kill -9 $PID1


		mkdir -p ./out/segs/h264/${res_}/${crf}/${filename}/

		# 1-second GOP: round the source frame rate to an integer
		fps=60
		gop=$(printf '%.0f' "$(echo "scale=5; $fps" | bc)")


		nohup /home/cc/bin/cham_monitor ./out/segs/h264/${res_}/${crf}/${filename}/energy.csv > stdout/sigh1.out &
		PID2=$!
		sleep 5

		ffmpeg -i "$file" \
		       -vf scale=${res} \
		       -c:v libx264 -preset veryfast -tune zerolatency -crf $crf \
		       -x264-params "keyint=${gop}:min-keyint=${gop}:scenecut=0:open-gop=0" \
		       -pix_fmt yuv420p \
		       -f dash \
		       -seg_duration 1 \
		       -frag_duration 0.2 \
		       -frag_type duration \
		       -ldash 1 \
		       -streaming 1 \
		       -use_template 1 -use_timeline 0 \
		       -write_prft 1 \
		       -target_latency 1 \
		       -utc_timing_url "https://time.akamai.com/?iso" \
		       -init_seg_name 'init-$RepresentationID$.m4s' \
		       -media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
		       "./out/segs/h264/${res_}/${crf}/${filename}/manifest.mpd"


		sleep 5
		
		kill -9 $PID2

		end_time=$(date +%s%3N)
		elapsed=$((end_time - start_time))
		echo "H.264 $filename $res_ $crf : Execution time : $elapsed ms"
		
	    done
	done
	
    fi
done
