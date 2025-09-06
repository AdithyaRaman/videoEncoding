#!/bin/bash


# ffmpeg -re -i $1 \
#   -map 0:v:0 -b:a 128k \
#   -filter:v:0 "scale=w=320:h=240"  -c:v:0 libx264 -b:v:0 145k  -maxrate:v:0 145k -bufsize:v:0 290k \
#   -filter:v:0 "scale=w=320:h=240"  -c:v:0 libx264 -b:v:1 240k  -maxrate:v:1 240k -bufsize:v:1 480k \
#   -keyint_min 60 -g 60 -sc_threshold 0 -preset veryfast -tune zerolatency \
#   -use_template 1 -use_timeline 1 -init_seg_name 'init-$RepresentationID$.m4s' \
#   -media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
#   -seg_duration 1 -ldash 1 -frag_duration 0.2 \
#   -adaptation_sets "id=0,streams=v id=1,streams=a" \
#   -f dash segments/manifest.mpd



ffmpeg -re -i $1   \
-filter_complex "\
 [0:v]split=32[v1][v2][v3][v4][v5][v6][v7][v8][v9][v10][v11][v12][v13][v14][v15][v16][v17][v18][v19][v20][v21][v22][v23][v24][v25][v26][v27][v28][v29][v30][v31][v32]; \
 [v1]scale=320:240[v1out]; \
 [v2]scale=320:240[v2out]; \
 [v3]scale=640:360[v3out]; \
 [v4]scale=640:360[v4out]; \
[v5]scale=640:360[v5out]; \
[v6]scale=640:360[v6out]; \
[v7]scale=640:360[v7out]; \
[v8]scale=960:540[v8out]; \
[v9]scale=640:480[v9out]; \
[v10]scale=640:480[v10out]; \
[v11]scale=640:480[v11out]; \
[v12]scale=1280:720[v12out]; \
[v13]scale=1280:720[v13out]; \
[v14]scale=1280:720[v14out]; \
[v15]scale=1280:720[v15out]; \
[v16]scale=1280:720[v16out]; \
[v17]scale=1920:1080[v17out]; \
[v18]scale=1280:720[v18out]; \
[v19]scale=1280:720[v19out]; \
[v20]scale=1280:720[v20out]; \
[v21]scale=1280:720[v21out]; \
[v22]scale=1920:1080[v22out]; \
[v23]scale=1920:1080[v23out]; \
[v24]scale=1920:1080[v24out]; \
[v25]scale=1920:1080[v25out]; \
[v26]scale=1920:1080[v26out]; \
[v27]scale=1920:1080[v27out]; \
[v28]scale=1920:1080[v28out]; \
[v29]scale=1920:1080[v29out]; \
[v30]scale=2560:1440[v30out]; \
[v31]scale=2560:1440[v31out]; \
[v32]scale=2560:1440[v32out]" \
       -map "[v1out]" -c:v:0 libx264 -b:v:0 145k -minrate:v:0 145k -maxrate:v:0 145k -bufsize:v:0 290k \
       -map "[v2out]" -c:v:1 libx264 -b:v:1 240k -minrate:v:1 240k -maxrate:v:1 240k -bufsize:v:1 480k \
       -map "[v3out]" -c:v:2 libx264 -b:v:2 365k -minrate:v:2 365k -maxrate:v:2 365k -bufsize:v:2 730k \
       -map "[v4out]" -c:v:3 libx264 -b:v:3 500k -minrate:v:3 500k -maxrate:v:3 500k -bufsize:v:3 1000k \
       -map "[v5out]" -c:v:4 libx264 -b:v:4 600k -minrate:v:4 600k -maxrate:v:4 600k -bufsize:v:4 1200k \
       -map "[v6out]" -c:v:5 libx264 -b:v:5 750k -minrate:v:5 750k -maxrate:v:5 750k -bufsize:v:5 1500k \
       -map "[v7out]" -c:v:6 libx264 -b:v:6 900k -minrate:v:6 900k -maxrate:v:6 900k -bufsize:v:6 1800k \
       -map "[v8out]" -c:v:7 libx264 -b:v:7 1000k -minrate:v:7 1000k -maxrate:v:7 1000k -bufsize:v:7 2000k \
       -map "[v9out]" -c:v:8 libx264 -b:v:8 1100k -minrate:v:8 1100k -maxrate:v:8 1100k -bufsize:v:8 2200k \
       -map "[v10out]" -c:v:9 libx264 -b:v:9 1200k -minrate:v:9 1200k -maxrate:v:9 1200k -bufsize:v:9 2400k \
       -map "[v11out]" -c:v:10 libx264 -b:v:10 1400k -minrate:v:10 1400k -maxrate:v:10 1400k -bufsize:v:10 2800k \
       -map "[v12out]" -c:v:11 libx264 -b:v:11 1600k -minrate:v:11 1600k -maxrate:v:11 1600k -bufsize:v:11 3200k \
       -map "[v13out]" -c:v:12 libx264 -b:v:12 1800k -minrate:v:12 1800k -maxrate:v:12 1800k -bufsize:v:12 3600k \
       -map "[v14out]" -c:v:13 libx264 -b:v:13 2000k -minrate:v:13 2000k -maxrate:v:13 2000k -bufsize:v:13 4000k \
       -map "[v15out]" -c:v:14 libx264 -b:v:14 2250k -minrate:v:14 2250k -maxrate:v:14 2250k -bufsize:v:14 4500k \
       -map "[v16out]" -c:v:15 libx264 -b:v:15 2500k -minrate:v:15 2500k -maxrate:v:15 2500k -bufsize:v:15 5000k \
       -map "[v17out]" -c:v:16 libx264 -b:v:16 2800k -minrate:v:16 2800k -maxrate:v:16 2800k -bufsize:v:16 5600k \
       -map "[v18out]" -c:v:17 libx264 -b:v:17 3000k -minrate:v:17 3000k -maxrate:v:17 3000k -bufsize:v:17 6000k \
       -map "[v19out]" -c:v:18 libx264 -b:v:18 3200k -minrate:v:18 3200k -maxrate:v:18 3200k -bufsize:v:18 6400k \
       -map "[v20out]" -c:v:19 libx264 -b:v:19 3400k -minrate:v:19 3400k -maxrate:v:19 3400k -bufsize:v:19 6800k \
       -map "[v21out]" -c:v:20 libx264 -b:v:20 3750k -minrate:v:20 3750k -maxrate:v:20 3750k -bufsize:v:20 7500k \
       -map "[v22out]" -c:v:21 libx264 -b:v:21 4000k -minrate:v:21 4000k -maxrate:v:21 4000k -bufsize:v:21 8000k \
       -map "[v23out]" -c:v:22 libx264 -b:v:22 4300k -minrate:v:22 4300k -maxrate:v:22 4300k -bufsize:v:22 8600k \
       -map "[v24out]" -c:v:23 libx264 -b:v:23 4500k -minrate:v:23 4500k -maxrate:v:23 4500k -bufsize:v:23 9000k \
       -map "[v25out]" -c:v:24 libx264 -b:v:24 5000k -minrate:v:24 5000k -maxrate:v:24 5000k -bufsize:v:24 10000k \
       -map "[v26out]" -c:v:25 libx264 -b:v:25 5500k -minrate:v:25 5500k -maxrate:v:25 5500k -bufsize:v:25 11000k \
       -map "[v27out]" -c:v:26 libx264 -b:v:26 6000k -minrate:v:26 6000k -maxrate:v:26 6000k -bufsize:v:26 12000k \
       -map "[v28out]" -c:v:27 libx264 -b:v:27 6500k -minrate:v:27 6500k -maxrate:v:27 6500k -bufsize:v:27 13000k \
       -map "[v29out]" -c:v:28 libx264 -b:v:28 7000k -minrate:v:28 7000k -maxrate:v:28 7000k -bufsize:v:28 14000k \
       -map "[v30out]" -c:v:29 libx264 -b:v:29 12000k -minrate:v:29 12000k -maxrate:v:29 12000k -bufsize:v:29 24000k \
       -map "[v31out]" -c:v:30 libx264 -b:v:30 15000k -minrate:v:30 15000k -maxrate:v:30 15000k -bufsize:v:30 30000k \
       -map "[v32out]" -c:v:31 libx264 -b:v:31 18000k -minrate:v:31 18000k -maxrate:v:31 18000k -bufsize:v:31 36000k \
-keyint_min 60 -g 60 -sc_threshold 0 -preset veryfast -tune zerolatency \
-use_template 1 -use_timeline 1 \
-init_seg_name 'init-$RepresentationID$.m4s' \
-media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
-seg_duration 1 -frag_duration 0.2 -ldash 1 \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
-f dash segments/$2/manifest.mpd
