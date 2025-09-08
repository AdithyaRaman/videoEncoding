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
       -map "[v1out]" -c:v:0 libvpx-vp9 -b:v:0 101k -minrate:v:0 101k -maxrate:v:0 101k -bufsize:v:0 202k \
       -map "[v2out]" -c:v:1 libvpx-vp9 -b:v:1 168k -minrate:v:1 168k -maxrate:v:1 168k -bufsize:v:1 360k \
       -map "[v3out]" -c:v:2 libvpx-vp9 -b:v:2 255k -minrate:v:2 255k -maxrate:v:2 255k -bufsize:v:2 546k \
       -map "[v4out]" -c:v:3 libvpx-vp9 -b:v:3 350k -minrate:v:3 350k -maxrate:v:3 350k -bufsize:v:3 750k \
       -map "[v5out]" -c:v:4 libvpx-vp9 -b:v:4 420k -minrate:v:4 420k -maxrate:v:4 420k -bufsize:v:4 900k \
       -map "[v6out]" -c:v:5 libvpx-vp9 -b:v:5 525k -minrate:v:5 525k -maxrate:v:5 525k -bufsize:v:5 1124k \
       -map "[v7out]" -c:v:6 libvpx-vp9 -b:v:6 630k -minrate:v:6 630k -maxrate:v:6 630k -bufsize:v:6 1350k \
       -map "[v8out]" -c:v:7 libvpx-vp9 -b:v:7 700k -minrate:v:7 700k -maxrate:v:7 700k -bufsize:v:7 1500k \
       -map "[v9out]" -c:v:8 libvpx-vp9 -b:v:8 770k -minrate:v:8 770k -maxrate:v:8 770k -bufsize:v:8 1650k \
       -map "[v10out]" -c:v:9 libvpx-vp9 -b:v:9 940k -minrate:v:9 940k -maxrate:v:9 940k -bufsize:v:9 1800k \
       -map "[v11out]" -c:v:10 libvpx-vp9 -b:v:10 979k -minrate:v:10 979k -maxrate:v:10 979k -bufsize:v:10 2100k \
       -map "[v12out]" -c:v:11 libvpx-vp9 -b:v:11 1120k -minrate:v:11 1120k -maxrate:v:11 1120k -bufsize:v:11 2400k \
       -map "[v13out]" -c:v:12 libvpx-vp9 -b:v:12 1260k -minrate:v:12 1260k -maxrate:v:12 1260k -bufsize:v:12 2700k \
       -map "[v14out]" -c:v:13 libvpx-vp9 -b:v:13 1400k -minrate:v:13 1400k -maxrate:v:13 1400k -bufsize:v:13 3000k \
       -map "[v15out]" -c:v:14 libvpx-vp9 -b:v:14 1575k -minrate:v:14 1575k -maxrate:v:14 1575k -bufsize:v:14 3354k \
       -map "[v16out]" -c:v:15 libvpx-vp9 -b:v:15 1750k -minrate:v:15 1750k -maxrate:v:15 1750k -bufsize:v:15 3650k \
       -map "[v17out]" -c:v:16 libvpx-vp9 -b:v:16 1959k -minrate:v:16 1959k -maxrate:v:16 1959k -bufsize:v:16 4200k \
       -map "[v18out]" -c:v:17 libvpx-vp9 -b:v:17 2100k -minrate:v:17 2100k -maxrate:v:17 2100k -bufsize:v:17 4500k \
       -map "[v19out]" -c:v:18 libvpx-vp9 -b:v:18 2240k -minrate:v:18 2240k -maxrate:v:18 2240k -bufsize:v:18 4800k \
       -map "[v20out]" -c:v:19 libvpx-vp9 -b:v:19 2380k -minrate:v:19 2380k -maxrate:v:19 2380k -bufsize:v:19 5100k \
       -map "[v21out]" -c:v:20 libvpx-vp9 -b:v:20 2625k -minrate:v:20 2625k -maxrate:v:20 2625k -bufsize:v:20 5624k \
       -map "[v22out]" -c:v:21 libvpx-vp9 -b:v:21 2800k -minrate:v:21 2800k -maxrate:v:21 2800k -bufsize:v:21 6000k \
       -map "[v23out]" -c:v:22 libvpx-vp9 -b:v:22 3010k -minrate:v:22 3010k -maxrate:v:22 3010k -bufsize:v:22 6420k \
       -map "[v24out]" -c:v:23 libvpx-vp9 -b:v:23 3150k -minrate:v:23 3150k -maxrate:v:23 3150k -bufsize:v:23 6700k \
       -map "[v25out]" -c:v:24 libvpx-vp9 -b:v:24 3500k -minrate:v:24 3500k -maxrate:v:24 3500k -bufsize:v:24 7500k \
       -map "[v26out]" -c:v:25 libvpx-vp9 -b:v:25 3849k -minrate:v:25 3849k -maxrate:v:25 3849k -bufsize:v:25 8250k \
       -map "[v27out]" -c:v:26 libvpx-vp9 -b:v:26 4200k -minrate:v:26 4200k -maxrate:v:26 4200k -bufsize:v:26 9000k \
       -map "[v28out]" -c:v:27 libvpx-vp9 -b:v:27 4550k -minrate:v:27 4550k -maxrate:v:27 4550k -bufsize:v:27 9700k \
       -map "[v29out]" -c:v:28 libvpx-vp9 -b:v:28 4900k -minrate:v:28 4900k -maxrate:v:28 4900k -bufsize:v:28 10500k \
       -map "[v30out]" -c:v:29 libvpx-vp9 -b:v:29 9400k -minrate:v:29 9400k -maxrate:v:29 9400k -bufsize:v:29 18000k \
       -map "[v31out]" -c:v:30 libvpx-vp9 -b:v:30 10500k -minrate:v:30 10500k -maxrate:v:30 10500k -bufsize:v:30 22500k \
       -map "[v32out]" -c:v:31 libvpx-vp9 -b:v:31 12600k -minrate:v:31 12600k -maxrate:v:31 12600k -bufsize:v:31 27000k \
-keyint_min 60 -g 60 -sc_threshold 0 -preset veryfast  \
-use_template 1 -use_timeline 1 \
-init_seg_name 'init-$RepresentationID$.m4s' \
-media_seg_name 'chunk-$RepresentationID$-$Number%05d$.m4s' \
-seg_duration 1 -frag_duration 0.2 -ldash 1 \
-adaptation_sets "id=0,streams=v id=1,streams=a" \
-f dash m31_segments/$2/manifest.mpd
