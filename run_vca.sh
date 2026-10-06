#!/bin/bash


for file in ~/inter4k_30fps/*.mp4;do
    if [ -f "$file" ];then
	filename=$(basename "$file")
	filename="${filename%.mp4}"
	ffmpeg -i $file -f yuv4mpegpipe - | vca --y4m --input stdin --complexity-csv ./out/vca/${filename}_vca.csv
    fi

done

    
