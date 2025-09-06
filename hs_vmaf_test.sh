#!/bin/bash


ffmpeg-quality-metrics -r 60 ./test_videos/h264/60/encodedVideos/lowmed/lowmed-12000k-2560x1440-60-h264.mp4 ./test_videos/h264/60/2KdownSampled/lowmed_2k_h264_60.mp4  --vmaf-model-params enable_conf_interval=true --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -t 4 -of csv >> lowmed_2k.csv

ffmpeg-quality-metrics -r 60 ./test_videos/h264/60/encodedVideos/lowmed/lowmed-5000k-1920x1080-60-h264.mp4 ./test_videos/h264/60/2KdownSampled/lowmed_2k_h264_60.mp4  --vmaf-model-params enable_conf_interval=true --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -t 4 -of csv >> lowmed_1080p.csv

# ffmpeg-quality-metrics -r 60 ./test_videos/h264/60/encodedVideos/lowmed/lowmed-240k-320x240-60-h264.mp4 ./test_videos/h264/60/2KdownSampled/lowmed_2k_h264_60.mp4  --vmaf-model-params  enable_transform=true enable_conf_interval=true --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -t 4 -of csv >> lowmed_240p_phone.csv

# ffmpeg-quality-metrics -r 60 ./test_videos/h264/60/encodedVideos/lowmed/lowmed-750k-640x360-60-h264.mp4 ./test_videos/h264/60/2KdownSampled/lowmed_2k_h264_60.mp4  --vmaf-model-params  enable_transform=true enable_conf_interval=true --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -t 4 -of csv >> lowmed_360p_phone.csv
