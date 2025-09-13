#!/bin/bash

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
       -map "[v1out]" -c:v:0 libaom-av1 -b:v:0 72k -minrate:v:0 72k -maxrate:v:0 72k -bufsize:v:0 144k \
       -map "[v2out]" -c:v:1 libaom-av1 -b:v:1 120k -minrate:v:1 120k -maxrate:v:1 120k -bufsize:v:1 240k \
       -map "[v3out]" -c:v:2 libaom-av1 -b:v:2 182k -minrate:v:2 182k -maxrate:v:2 182k -bufsize:v:2 364k \
       -map "[v4out]" -c:v:3 libaom-av1 -b:v:3 250k -minrate:v:3 250k -maxrate:v:3 250k -bufsize:v:3 500k \
       -map "[v5out]" -c:v:4 libaom-av1 -b:v:4 300k -minrate:v:4 300k -maxrate:v:4 300k -bufsize:v:4 600k \
       -map "[v6out]" -c:v:5 libaom-av1 -b:v:5 375k -minrate:v:5 375k -maxrate:v:5 375k -bufsize:v:5 750k \
       -map "[v7out]" -c:v:6 libaom-av1 -b:v:6 450k -minrate:v:6 450k -maxrate:v:6 450k -bufsize:v:6 900k \
       -map "[v8out]" -c:v:7 libaom-av1 -b:v:7 500k -minrate:v:7 500k -maxrate:v:7 500k -bufsize:v:7 1000k \
       -map "[v9out]" -c:v:8 libaom-av1 -b:v:8 550k -minrate:v:8 550k -maxrate:v:8 550k -bufsize:v:8 1100k \
       -map "[v10out]" -c:v:9 libaom-av1 -b:v:9 600k -minrate:v:9 600k -maxrate:v:9 600k -bufsize:v:9 1200k \
       -map "[v11out]" -c:v:10 libaom-av1 -b:v:10 700k -minrate:v:10 700k -maxrate:v:10 700k -bufsize:v:10 1400k \
       -map "[v12out]" -c:v:11 libaom-av1 -b:v:11 800k -minrate:v:11 800k -maxrate:v:11 800k -bufsize:v:11 1600k \
       -map "[v13out]" -c:v:12 libaom-av1 -b:v:12 900k -minrate:v:12 900k -maxrate:v:12 900k -bufsize:v:12 1800k \
       -map "[v14out]" -c:v:13 libaom-av1 -b:v:13 1000k -minrate:v:13 1000k -maxrate:v:13 1000k -bufsize:v:13 2000k \
       -map "[v15out]" -c:v:14 libaom-av1 -b:v:14 1125k -minrate:v:14 1125k -maxrate:v:14 1125k -bufsize:v:14 2250k \
       -map "[v16out]" -c:v:15 libaom-av1 -b:v:15 1250k -minrate:v:15 1250k -maxrate:v:15 1250k -bufsize:v:15 2500k \
       -map "[v17out]" -c:v:16 libaom-av1 -b:v:16 1400k -minrate:v:16 1400k -maxrate:v:16 1400k -bufsize:v:16 2800k \
       -map "[v18out]" -c:v:17 libaom-av1 -b:v:17 1500k -minrate:v:17 1500k -maxrate:v:17 1500k -bufsize:v:17 3000k \
       -map "[v19out]" -c:v:18 libaom-av1 -b:v:18 1600k -minrate:v:18 1600k -maxrate:v:18 1600k -bufsize:v:18 3200k \
       -map "[v20out]" -c:v:19 libaom-av1 -b:v:19 1700k -minrate:v:19 1700k -maxrate:v:19 1700k -bufsize:v:19 3400k \
       -map "[v21out]" -c:v:20 libaom-av1 -b:v:20 1875k -minrate:v:20 1875k -maxrate:v:20 1875k -bufsize:v:20 3750k \
       -map "[v22out]" -c:v:21 libaom-av1 -b:v:21 2000k -minrate:v:21 2000k -maxrate:v:21 2000k -bufsize:v:21 4000k \
       -map "[v23out]" -c:v:22 libaom-av1 -b:v:22 2150k -minrate:v:22 2150k -maxrate:v:22 2150k -bufsize:v:22 4300k \
       -map "[v24out]" -c:v:23 libaom-av1 -b:v:23 2250k -minrate:v:23 2250k -maxrate:v:23 2250k -bufsize:v:23 4500k \
       -map "[v25out]" -c:v:24 libaom-av1 -b:v:24 2500k -minrate:v:24 2500k -maxrate:v:24 2500k -bufsize:v:24 5000k \
       -map "[v26out]" -c:v:25 libaom-av1 -b:v:25 2750k -minrate:v:25 2750k -maxrate:v:25 2750k -bufsize:v:25 5500k \
       -map "[v27out]" -c:v:26 libaom-av1 -b:v:26 3000k -minrate:v:26 3000k -maxrate:v:26 3000k -bufsize:v:26 6000k \
       -map "[v28out]" -c:v:27 libaom-av1 -b:v:27 3250k -minrate:v:27 3250k -maxrate:v:27 3250k -bufsize:v:27 6500k \
       -map "[v29out]" -c:v:28 libaom-av1 -b:v:28 3500k -minrate:v:28 3500k -maxrate:v:28 3500k -bufsize:v:28 7000k \
       -map "[v30out]" -c:v:29 libaom-av1 -b:v:29 6000k -minrate:v:29 6000k -maxrate:v:29 6000k -bufsize:v:29 12000k \
       -map "[v31out]" -c:v:30 libaom-av1 -b:v:30 7500k -minrate:v:30 7500k -maxrate:v:30 7500k -bufsize:v:30 15000k \
       -map "[v32out]" -c:v:31 libaom-av1 -b:v:31 9000k -minrate:v:31 9000k -maxrate:v:31 9000k -bufsize:v:31 18000k \
-keyint_min 60 -g 60 -sc_threshold 0 -usage realtime -cpu-used 8 -preset veryfast  \
-use_template 1 -use_timeline 1 \
-init_seg_name 'init-$RepresentationID$.m4s' \
-media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
-seg_duration 1 -frag_duration 0.2 -ldash 1 \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
-f dash m31_segments/$2/manifest.mpd
