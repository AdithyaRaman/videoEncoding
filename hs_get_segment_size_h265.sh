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
       -map "[v1out]" -c:v:0 libx265 -b:v:0 145k -minrate:v:0 108k -maxrate:v:0 108k -bufsize:v:0 216k \
       -map "[v2out]" -c:v:1 libx265 -b:v:1 180k -minrate:v:1 180k -maxrate:v:1 180k -bufsize:v:1 360k \
       -map "[v3out]" -c:v:2 libx265 -b:v:2 273k -minrate:v:2 273k -maxrate:v:2 273k -bufsize:v:2 546k \
       -map "[v4out]" -c:v:3 libx265 -b:v:3 375k -minrate:v:3 375k -maxrate:v:3 375k -bufsize:v:3 750k \
       -map "[v5out]" -c:v:4 libx265 -b:v:4 450k -minrate:v:4 450k -maxrate:v:4 450k -bufsize:v:4 900k \
       -map "[v6out]" -c:v:5 libx265 -b:v:5 562k -minrate:v:5 562k -maxrate:v:5 562k -bufsize:v:5 1124k \
       -map "[v7out]" -c:v:6 libx265 -b:v:6 675k -minrate:v:6 675k -maxrate:v:6 675k -bufsize:v:6 1350k \
       -map "[v8out]" -c:v:7 libx265 -b:v:7 750k -minrate:v:7 750k -maxrate:v:7 750k -bufsize:v:7 1500k \
       -map "[v9out]" -c:v:8 libx265 -b:v:8 825k -minrate:v:8 825k -maxrate:v:8 825k -bufsize:v:8 1650k \
       -map "[v10out]" -c:v:9 libx265 -b:v:9 900k -minrate:v:9 900k -maxrate:v:9 900k -bufsize:v:9 1800k \
       -map "[v11out]" -c:v:10 libx265 -b:v:10 1050k -minrate:v:10 1050k -maxrate:v:10 1050k -bufsize:v:10 2100k \
       -map "[v12out]" -c:v:11 libx265 -b:v:11 1200k -minrate:v:11 1200k -maxrate:v:11 1200k -bufsize:v:11 2400k \
       -map "[v13out]" -c:v:12 libx265 -b:v:12 1350k -minrate:v:12 1350k -maxrate:v:12 1350k -bufsize:v:12 2700k \
       -map "[v14out]" -c:v:13 libx265 -b:v:13 1500k -minrate:v:13 1500k -maxrate:v:13 1500k -bufsize:v:13 3000k \
       -map "[v15out]" -c:v:14 libx265 -b:v:14 1687k -minrate:v:14 1687k -maxrate:v:14 1687k -bufsize:v:14 3354k \
       -map "[v16out]" -c:v:15 libx265 -b:v:15 1875k -minrate:v:15 1875k -maxrate:v:15 1875k -bufsize:v:15 3650k \
       -map "[v17out]" -c:v:16 libx265 -b:v:16 2100k -minrate:v:16 2100k -maxrate:v:16 2100k -bufsize:v:16 4200k \
       -map "[v18out]" -c:v:17 libx265 -b:v:17 2250k -minrate:v:17 2250k -maxrate:v:17 2250k -bufsize:v:17 4500k \
       -map "[v19out]" -c:v:18 libx265 -b:v:18 2400k -minrate:v:18 2400k -maxrate:v:18 2400k -bufsize:v:18 4800k \
       -map "[v20out]" -c:v:19 libx265 -b:v:19 2550k -minrate:v:19 2550k -maxrate:v:19 2550k -bufsize:v:19 5100k \
       -map "[v21out]" -c:v:20 libx265 -b:v:20 2812k -minrate:v:20 2812k -maxrate:v:20 2812k -bufsize:v:20 5624k \
       -map "[v22out]" -c:v:21 libx265 -b:v:21 3000k -minrate:v:21 3000k -maxrate:v:21 3000k -bufsize:v:21 6000k \
       -map "[v23out]" -c:v:22 libx265 -b:v:22 3225k -minrate:v:22 3225k -maxrate:v:22 3225k -bufsize:v:22 6450k \
       -map "[v24out]" -c:v:23 libx265 -b:v:23 3375k -minrate:v:23 3375k -maxrate:v:23 3375k -bufsize:v:23 6750k \
       -map "[v25out]" -c:v:24 libx265 -b:v:24 3750k -minrate:v:24 3750k -maxrate:v:24 3750k -bufsize:v:24 7500k \
       -map "[v26out]" -c:v:25 libx265 -b:v:25 4125k -minrate:v:25 4125k -maxrate:v:25 4125k -bufsize:v:25 8250k \
       -map "[v27out]" -c:v:26 libx265 -b:v:26 4500k -minrate:v:26 4500k -maxrate:v:26 4500k -bufsize:v:26 9000k \
       -map "[v28out]" -c:v:27 libx265 -b:v:27 4875k -minrate:v:27 4875k -maxrate:v:27 4875k -bufsize:v:27 9750k \
       -map "[v29out]" -c:v:28 libx265 -b:v:28 5250k -minrate:v:28 5250k -maxrate:v:28 5250k -bufsize:v:28 10500k \
       -map "[v30out]" -c:v:29 libx265 -b:v:29 9000k -minrate:v:29 9000k -maxrate:v:29 9000k -bufsize:v:29 18000k \
       -map "[v31out]" -c:v:30 libx265 -b:v:30 11250k -minrate:v:30 11250k -maxrate:v:30 11250k -bufsize:v:30 22500k \
       -map "[v32out]" -c:v:31 libx265 -b:v:31 13500k -minrate:v:31 13500k -maxrate:v:31 13500k -bufsize:v:31 27000k \
-keyint_min 60 -g 60 -sc_threshold 0 -preset veryfast -tune zerolatency \
-use_template 1 -use_timeline 1 \
-init_seg_name 'init-$RepresentationID$.m4s' \
-media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
-seg_duration 1 -frag_duration 0.2 -ldash 1 \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
-f dash m31_segments/$2/manifest.mpd
