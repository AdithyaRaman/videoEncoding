ximport os
import multiprocessing
import subprocess
import argparse
import time
import cv2

sample_videos = {
    #"low" :[137],
    "low": [  137,810, 586, 948, 365, 577, 971],
      "lowmed": [643, 515, 796, 705, 872, 429, 966],
      "med": [389, 740, 654, 97, 58, 105, 878],
      "medhigh": [997, 575, 516, 31, 606, 394, 223],
      "high": [977, 47, 788, 19, 84, 369, 297],
      "superhigh": [794, 899, 928, 541, 942, 629, 617]
}


def parse_args():
    parser = argparse.ArgumentParser()



    parser.add_argument('-c', '--codec', dest='codec', help='Codec (Eg h264)',
    			default='h264', type=str)
    parser.add_argument('-f', '--fps', dest='fps', help='FPS',
    			default='60', type=str)

    args = parser.parse_args()
    return args

ARGS = parse_args()

INTER4KPATH = "/home/cc/workspace/videoDataSet/Inter4K/60fps/UHD/"
OUTPUTDIR = "./inter4k/"
#bitrate ladder: 360p, 480p, 720p, 1080p, 2k
#bitrate = 600, res = 360p

def encode(b,r,videoId, fps):
    maxRate = "{}k".format(int(b)*1.2)
    bufSize = "{}k".format(int(b)*5)
    keyInt = int(fps)
    keyIntMin = int(fps)
    
    outputFileId = f"{videoId}-{b}k-{r.split(':')[0]}x{r.split(':')[1]}-{round(fps)}-{ARGS.codec}"
    inputFile = f"{INTER4KPATH}{videoId}.mp4"

    """
    DOWNSAMPLING from 4K to 2K
    """
    downSampleVidFile = f"{downSampleDir}/{videoId}_2k_{ARGS.codec}_{ARGS.fps}.mp4"
    #downSampleVidFile = f"{downSampleDir}/{videoId}_2k.mp4"
    
    """
    FFMPEG Encoding
    """
    
    if ARGS.codec=="h264":
        cmdFfmpeg = f"ffmpeg -y -i {downSampleVidFile} -vf scale={r} -vcodec libx264 -b:v {b}k -c:v libx264 -r {fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -an {encodedVideoDir}/{outputFileId}.mp4"
    elif ARGS.codec=="h265":
        cmdFfmpeg = f"ffmpeg -y -i {downSampleVidFile} -vf scale={r} -vcodec libx265 -b:v {b}k -c:v libx265 -r {fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -an {encodedVideoDir}/{outputFileId}.mp4"
    elif ARGS.codec=="av1":
        cmdFfmpeg = f"ffmpeg -y -i {downSampleVidFile} -vf scale={r} -vcodec libaom-av1 -b:v {b}k -c:v libaom-av1 -r {fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -cpu-used 4 -crf 30 -an {encodedVideoDir}/{outputFileId}.mp4"
        


    ffmpeg_start_time = time.time()
    #os.system(cmdFfmpeg)
    ffmpeg_end_time = time.time()
    print(f"FFMPEG Time:{ffmpeg_end_time-ffmpeg_start_time}")


    """
    Segment Size Calculation
    """
    cmdSize = f"ffprobe -show_entries frame=pkt_size,pkt_pts_time -print_format csv {encodedVideoDir}/{outputFileId}.mp4 > {videoSizeDir}/{outputFileId}.csv"

    size_start_time = time.time()
    #os.system(cmdSize)
    size_end_time = time.time()
    print(f"Size calc time:{size_end_time-size_start_time}")

    """
    Run quality measures
    """
    cmdQuality = f"ffmpeg-quality-metrics {encodedVideoDir}/{outputFileId}.mp4 {downSampleVidFile} --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -of csv >> {videoQualityDir}/{outputFileId}.csv"
    quality_start_time = time.time()
    os.system(cmdQuality)
    quality_end_time = time.time()
    print(f"Quality time:{quality_end_time-quality_start_time}")

    """
    Run XPSNR Calculation
    """
    cmdXpsnr = f" ffmpeg -r {fps} -i {downSampleVidFile} -r {fps} -i {encodedVideoDir}/{outputFileId}.mp4 -lavfi '[1:v]scale=2460:1440[scaled];[0:v][scaled]xpsnr=stats_file={xpsnrDir}/{outputFileId}.csv'  -f null -"
    xpsnr_start_time = time.time()
    #os.system(cmdXpsnr)
    xpsnr_end_time = time.time()
    print(f"XPSNR time:{xpsnr_end_time-xpsnr_start_time}")



    
if __name__=="__main__":
    # start_time = time.time()
    # encode("600","480:360","131")
    # end_time = time.time()
    #print(f"Total time:{end_time-start_time}")

    # low_bitrate_ladder = [
    #     ("450","480:360"),
    #     ("750","480:360"),
    #     ("1000","640:480"),
    #     ("1200","640:480"),
    #     ("1850","1280:720"),
    #     ("2500","1280:720"),
    #     ("3200","1920:1080"),
    #     ("5000","1920:1080"),
    #     ("7000","2460:1440"),
    #     ("9000","2460:1440"),
    # ]

    low_bitrate_ladder = [
            ("300","480:360"),
            ("450","480:360"),
            ("700","640:480"),
            ("850","640:480"),
            ("1350","1280:720"),
            ("2000","1280:720"),
            ("2500","1920:1080"),
            ("3000","1920:1080"),
            ("5000","2460:1440"),
            ("7000","2460:1440"),
        ]

    if ARGS.codec == "h264":

        low_bitrate_ladder = low_bitrate_ladder
        lowmed_bitrate_ladder = [ (int(int(k[0])*1.2),k[1]) for k in low_bitrate_ladder]
        med_bitrate_ladder = [ (int(int(k[0])*1.2),k[1]) for k in lowmed_bitrate_ladder]
        medhigh_bitrate_ladder = [ (int(int(k[0])*1.2),k[1]) for k in med_bitrate_ladder]
        high_bitrate_ladder = [ (int(int(k[0])*1.2),k[1]) for k in medhigh_bitrate_ladder]
        superhigh_bitrate_ladder = [ (int(int(k[0])*1.2),k[1]) for k in high_bitrate_ladder]

    elif ARGS.codec == "h265":
        low_bitrate_ladder = [(int(int(k[0]) * 0.6), k[1]) for k in low_bitrate_ladder]
        lowmed_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in low_bitrate_ladder]
        med_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in lowmed_bitrate_ladder]
        medhigh_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in med_bitrate_ladder]
        high_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in medhigh_bitrate_ladder]
        superhigh_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in high_bitrate_ladder]

    elif ARGS.codec == "av1":
        low_bitrate_ladder = [(int(int(k[0]) * 0.45), k[1]) for k in low_bitrate_ladder]
        lowmed_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in low_bitrate_ladder]
        med_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in lowmed_bitrate_ladder]
        medhigh_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in med_bitrate_ladder]
        high_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in medhigh_bitrate_ladder]
        superhigh_bitrate_ladder = [(int(int(k[0]) * 1.2), k[1]) for k in high_bitrate_ladder]


        
        
    comp_bitrate_ladder = {
        "low":low_bitrate_ladder,
        "lowmed":lowmed_bitrate_ladder,
        "med":med_bitrate_ladder,
        "medhigh":medhigh_bitrate_ladder,
        "high":high_bitrate_ladder,
        "superhigh":superhigh_bitrate_ladder
    }

    
    downSampleDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/2KdownSampled/"
    if not os.path.exists(downSampleDir):
         os.makedirs(downSampleDir)


    # videoId = 948
    # bitrate = "135"
    # res = "480:360"
    
    # encodedVideoDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/encodedVideos/{videoId}"
    # if not os.path.exists(encodedVideoDir):
    #     os.makedirs(encodedVideoDir)
        
    # videoSizeDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/segmentSize/{videoId}"
    # if not os.path.exists(videoSizeDir):
    #     os.makedirs(videoSizeDir)
        
    # videoQualityDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/videoQuality/{videoId}"
    # if not os.path.exists(videoQualityDir):
    #     os.makedirs(videoQualityDir)
        
    # xpsnrDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/xpsnr/{videoId}"
    # if not os.path.exists(xpsnrDir):
    #     os.makedirs(xpsnrDir)
    # encode(bitrate,res,videoId,int(ARGS.fps))
    
    for k in sample_videos:
        for videoId in sample_videos[k]:

            # inputFile = f"{INTER4KPATH}{videoId}.mp4"
            # cap = cv2.VideoCapture(inputFile)
            # fps = cap.get(cv2.CAP_PROP_FPS)
            # cap.release()

            if ARGS.codec=="h264":
                cmdDownSample = f"ffmpeg -y -i {INTER4KPATH}{videoId}.mp4 -vf scale=2460:1440 -vcodec libx264 -b:v 20000k -c:v libx264 -r {ARGS.fps}  -an {downSampleDir}/{videoId}_2k_{ARGS.codec}_{ARGS.fps}.mp4"
            elif ARGS.codec=="h265":
                cmdDownSample = f"ffmpeg -y -i {INTER4KPATH}{videoId}.mp4 -vf scale=2460:1440 -vcodec libx265 -b:v 12000k -c:v libx265 -r {ARGS.fps}  -an {downSampleDir}/{videoId}_2k_{ARGS.codec}_{ARGS.fps}.mp4"
            elif ARGS.codec=="av1":
                cmdDownSample = f"ffmpeg -y -i {INTER4KPATH}{videoId}.mp4 -vf scale=2460:1440 -vcodec libaom-av1 -b:v 9000k -c:v libaom-av1 -cpu-used 4 -crf 30 -r {ARGS.fps} -an {downSampleDir}/{videoId}_2k_{ARGS.codec}_{ARGS.fps}.mp4"


            
            os.system(cmdDownSample)
            
            encodedVideoDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/encodedVideos/{videoId}"
            if not os.path.exists(encodedVideoDir):
                os.makedirs(encodedVideoDir)
        
            videoSizeDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/segmentSize/{videoId}"
            if not os.path.exists(videoSizeDir):
                os.makedirs(videoSizeDir)
        
            videoQualityDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/videoQuality/{videoId}"
            if not os.path.exists(videoQualityDir):
                os.makedirs(videoQualityDir)
        
            xpsnrDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/xpsnr/{videoId}"
            if not os.path.exists(xpsnrDir):
                os.makedirs(xpsnrDir)

            p_args = comp_bitrate_ladder[k]
            p_args = [k+(videoId,int(ARGS.fps),) for k in p_args]
            
    
            # for p in p_args:
            #     encode(p[0],p[1],p[2],p[3])

            with multiprocessing.Pool(10) as pool:
                pool.starmap(encode,p_args)

