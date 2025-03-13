import os
import multiprocessing
import subprocess
import argparse

def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('-i', '--inputFile', dest='inputFile', help='Source Input File',
                        default='~/workspace/videoDataSet/og_videos/cosmoslaundromat/Cosmos_Laundromat_First_Cycle_2k.mp4', type=str)
    parser.add_argument('-r', '--resolution', dest='resolution', help='Resolution(Eg 1920:1080)',
    			default='1920:1080', type=str)
    parser.add_argument('-c', '--codec', dest='codec', help='Codec (Eg h264)',
    			default='h264', type=str)
    parser.add_argument('-b', '--bitrate', dest='bitrate', help='Bitrate (Eg 5800k)',
    			default='5800', type=str)
    parser.add_argument('-o','--outputFile', dest='outputFile', help='Output file',
    			default='test.mp4', type=str)
    parser.add_argument('-f', '--fps', dest='fps', help='Frame/Sec (Eg, 60)',
    			default=24, type=int)
    parser.add_argument('-v', '--videocomp', dest='videocomp', help='Video complexity',
    			default="low", type=str)

    args = parser.parse_args()
    return args


ARGS = parse_args()

def main(b,r):
        maxRate = "{}k".format(int(b)*1.2)
        bufSize = "{}k".format(int(b)*5)
        keyInt = int(ARGS.fps)
        keyIntMin = int(ARGS.fps)
        #fileName = ARGS.inputFile.split("/")[-1]
        
        downSampleVidFile = f"{downSampleDir}/{ARGS.outputFile}_2k_{ARGS.codec}_{ARGS.fps}.mp4"

        outputFileId = f"{ARGS.outputFile}-{b}k-{r.split(':')[0]}x{r.split(':')[1]}-{round(ARGS.fps)}-{ARGS.codec}"
        """
        FFMPEG Encoding
        """

        encodedVideoFile = f"{encodedVideoDir}/{outputFileId}.mp4"
        if ARGS.codec=="h264":
            #cmdFfmpeg = f"ffmpeg -i {downSampleVidFile} -vf scale={r} -vcodec libx264 -b:v {b}k -c:v libx264 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -keyint_min {keyIntMin}  -sc_threshold 0 -x264opts 'no-scenecut' -t 300  -an {encodedVideoFile}"

            #FFMPEG cmd with scene change detection
            cmdFfmpeg = f"ffmpeg -i {downSampleVidFile} -vf scale={r} -vcodec libx264 -b:v {b}k -c:v libx264 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -t 300  -an {encodedVideoFile}"
        elif ARGS.codec=="h265":
            cmdFfmpeg = f"ffmpeg -y -i {downSampleVidFile} -vf scale={r} -vcodec libx265 -b:v {b}k -c:v libx265 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -t 300 -an {encodedVideoFile}"
        elif ARGS.codec=="av1":
            cmdFfmpeg = f"ffmpeg -y -i {downSampleVidFile} -vf scale={r} -vcodec libaom-av1 -b:v {b}k -c:v libaom-av1 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -crf 30 -t 300 -an {encodedVideoFile}"
            
        # Start the encoding process
        os.system(cmdFfmpeg)
        

        """
        Segment Size Calculation
	"""
        # Segment Size calculation
        videoSizeFile = f"{videoSizeDir}/{outputFileId}.csv"
        
        cmdSize = f"ffprobe -show_entries frame=pkt_size,pkt_pts_time -print_format csv {encodedVideoFile} > {videoSizeFile}"

        os.system(cmdSize)

        
        """
	Run quality measures
	"""
        qualityOutputFile = f"{videoQualityDir}/{outputFileId}.csv"
        cmdQuality = f"ffmpeg-quality-metrics {encodedVideoFile} {downSampleVidFile} --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -t 4 -of csv >> {qualityOutputFile}"

        os.system(cmdQuality)


        """
        Run XPSNR Calculation
        """
        xpsnrOutputFile = f"{xpsnrDir}/{outputFileId}.txt"
        cmdXpsnr = f" ffmpeg -r {ARGS.fps} -i {downSampleVidFile} -r {ARGS.fps} -i {encodedVideoFile} -lavfi '[1:v]scale=2460:1440[scaled];[0:v][scaled]xpsnr=stats_file={xpsnrOutputFile}' -vframes {int(ARGS.fps)*300} -f null -"
        os.system(cmdXpsnr)
        #break



#videoTitle = f"{ARGS.outputFile}_{ARGS.codec}_{ARGS.fps}"

OUTPUTDIR = f"./test_videos/"

downSampleDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/2KdownSampled/"
if not os.path.exists(downSampleDir):
    os.makedirs(downSampleDir)

encodedVideoDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/encodedVideos/{ARGS.outputFile}"
if not os.path.exists(encodedVideoDir):
    os.makedirs(encodedVideoDir)
        
videoSizeDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/segmentSize/{ARGS.outputFile}"
if not os.path.exists(videoSizeDir):
    os.makedirs(videoSizeDir)
        
videoQualityDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/videoQuality/{ARGS.outputFile}"
if not os.path.exists(videoQualityDir):
    os.makedirs(videoQualityDir)
        
xpsnrDir = f"{OUTPUTDIR}/{ARGS.codec}/{ARGS.fps}/xpsnr/{ARGS.outputFile}"
if not os.path.exists(xpsnrDir):
    os.makedirs(xpsnrDir)
        

if __name__=="__main__":
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
    

    bitrates = comp_bitrate_ladder[ARGS.videocomp]
    
    #p_args = [(b,bitrates[b]) for b in bitrates]
    p_args = bitrates

    downSampleVidFile = f"{downSampleDir}/{ARGS.outputFile}_2k_{ARGS.codec}_{ARGS.fps}.mp4"
    if ARGS.codec=="h264":
        #cmdDownSample = f"ffmpeg -y -i {ARGS.inputFile} -vf scale=2460:1440 -vcodec libx264 -b:v 20000k -c:v libx264 -r {ARGS.fps} -sc_threshold 0 -x264opts 'no-scenecut' -an {downSampleVidFile}"
        cmdDownSample = f"ffmpeg -y -i {ARGS.inputFile} -vf scale=2460:1440 -vcodec libx264 -b:v 20000k -c:v libx264 -r {ARGS.fps} -an {downSampleVidFile}"
    elif ARGS.codec=="h265":
        cmdDownSample = f"ffmpeg -y -i {ARGS.inputFile} -vf scale=2460:1440 -vcodec libx265 -b:v 12000k -c:v libx265 -r {ARGS.fps}  -an {downSampleVidFile}"
    elif ARGS.codec=="av1":
        cmdDownSample = f"ffmpeg -y -i {ARGS.inputFile} -vf scale=2460:1440 -vcodec libaom-av1 -b:v 9000k -c:v libaom-av1 -crf 30 -r {ARGS.fps} -an {downSampleVidFile}"

    if f"{ARGS.outputFile}_2k_{ARGS.codec}_{ARGS.fps}.mp4" not in os.listdir(downSampleDir):
        os.system(cmdDownSample)



    with multiprocessing.Pool(10) as pool:
        pool.starmap(main,p_args)
            
    
