nimport os
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
    			default="24", type=str)
    parser.add_argument('-v', '--videocomp', dest='videocomp', help='Video complexity',
    			default="low", type=str)

    args = parser.parse_args()
    return args



ARGS = parse_args()

def main(b,r):
        maxRate = "{}k".format(int(b)*1.2)
        bufSize = "{}k".format(int(b)*5)
        keyInt = int(ARGS.fps)*2
        keyIntMin = int(ARGS.fps)*2
        fileName = ARGS.inputFile.split("/")[-1]
        outputFile = "{}-{}k-{}_{}.mp4".format(fileName[:-4], b, r.replace(':','x',1), ARGS.fps)
        """
        FFMPEG Encoding
        """
        if ARGS.codec=="h264":
            cmdFfmpeg = f"ffmpeg -i {ARGS.inputFile} -vf scale={r} -vcodec libx264 -b:v {b}k -c:v libx264 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -keyint_min {keyIntMin}  -sc_threshold 0 -x264opts 'no-scenecut' -t 300  -an {dirName}/{outputFile}"
        else:
            cmdFfmpeg = f"ffmpeg -i {ARGS.inputFile} -vf scale={r} -vcodec libx265 -b:v {b}k -c:v libx265 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -keyint_min {keyIntMin} -sc_threshold 0 -t 300 -an {dirName}/{outputFile}"

        
        # Start the encoding process
        #os.system(cmdFfmpeg)

        """
	Segmenting using MP4Box
	"""
        # Start the Segmenting process
        manifest_path = f"{manifestDir}/{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.mpd"

        if ARGS.codec=="h264":
            cmdMp4box = f"MP4Box -dash {1000} -rap -profile dashavc264:live -mpd-title {videoTitle} -out {manifest_path} -segment-name segments/dash_{b}k_%s_ -frag {200} {dirName}/{outputFile}"
        else:
            cmdMp4box = f"MP4Box -dash {1000} -rap -profile dashhvc265:live -mpd-title {videoTitle} -out {manifest_path} -segment-name segments/dash_{b}k_%s_ -frag {200} {dirName}/{outputFile}"

        os.system(cmdMp4box)

        """
        Segment Size Calculation
	"""
        # Segment Size calculation
        videoSizeFile = f"{videoSizeDir}/{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.csv"
        
        cmdSize = f"ffprobe -show_entries frame=pkt_size,pkt_pts_time -print_format csv {dirName}/{outputFile} > {videoSizeFile}"

        os.system(cmdSize)
        """
	Run quality measures
	"""
        qualityOutputFile = f"{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.csv"
        cmdQuality = f"ffmpeg-quality-metrics {dirName}/{outputFile} {ARGS.inputFile} --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -of csv >> {qualityDir}/{qualityOutputFile}"

        #os.system(cmdQuality)


        """
        Run XPSNR Calculation
        """
        xpsnrOutputFile = f"{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.txt"
        cmdXpsnr = f" ffmpeg -r {ARGS.fps} -i {ARGS.inputFile} -r {ARGS.fps} -i {dirName}/{outputFile} -lavfi '[1:v]scale=3840:1714[scaled];[0:v][scaled]xpsnr=stats_file={xpsnrDir}/{xpsnrOutputFile}' -vframes {int(ARGS.fps)*300} -f null -"
        #os.system(cmdXpsnr)
        #break



videoTitle = f"sintel_{ARGS.codec}_final"
    
dirName = f"encodedVideos/{videoTitle}"
if not os.path.exists(dirName):
    os.makedirs(dirName)
        
manifestDir = f"manifests/{videoTitle}"
if not os.path.exists(manifestDir):
    os.makedirs(manifestDir)

videoSizeDir = f"videoSizes/{videoTitle}"
if not os.path.exists(videoSizeDir):
    os.makedirs(videoSizeDir)

qualityDir = f"videoQuality/{videoTitle}"
if not os.path.exists(qualityDir):
    os.makedirs(qualityDir)

xpsnrDir = f"xpsnr_out/{videoTitle}"
if not os.path.exists(xpsnrDir):
    os.makedirs(xpsnrDir)
        
if __name__=="__main__":

    if ARGS.codec == "h264":
        # H264 Bitrate Ladder
        # Low
        bitrates_low = {
            "600":"480:360",
            "800":"480:360",
            "1000":"640:480",
            "1500":"640:480",
            "2500":"1280:720",
            "3500":"1280:720",
            "5000":"1920:1080",
            "7000":"1920:1080"
        }

        #Med
        bitrates_med = {
            "900":"480:360",
            "1200":"480:360",
            "1500":"640:480",
            "1850":"640:480",
            "3250":"1280:720",
            "4000":"1280:720",
            "6000":"1920:1080",
            "8000":"1920:1080"
        }

        #High
        bitrates_high = {
            "1200":"480:360",
            "1500":"480:360",
            "1750":"640:480",
            "2000":"640:480",
            "3750":"1280:720",
            "4500":"1280:720",
            "6500":"1920:1080",
            "9000":"1920:1080"
        }
        
    elif ARGS.codec == "h265":
        # H265 Bitrate Ladder
        # Low
        bitrates_low = {
            "300":"480:360",
            "450":"480:360",
            "750":"640:480",
            "900":"640:480",
            "2350":"1280:720",
            "3000":"1280:720",
            "4500":"1920:1080",
            "5000":"1920:1080"
        }

        #Med
        bitrates_mid = {
            "420":"480:360",
            "600":"480:360",
            "900":"640:480",
            "1250":"640:480",
            "2500":"1280:720",
            "3250":"1280:720",
            "5500":"1920:1080",
            "6500":"1920:1080"
        }

        #High
        bitrates_high = {
            "550":"480:360",
            "750":"480:360",
            "1000":"640:480",
            "1500":"640:480",
            "2850":"1280:720",
            "3750":"1280:720",
            "6000":"1920:1080",
            "8000":"1920:1080"
        }
    else :
        # AV1 Bitrate Ladder
        # Low
        pass

    
    if ARGS.videocomp == "low":
        bitrates = bitrates_low
    elif ARGS.videocomp == "med":
        bitrates = bitrates_med
    else:
        bitrates = bitrates_high
    
    p_args = [(b,bitrates[b]) for b in bitrates]
    
    #for b in bitrates:
    #     p = multiprocessing.Process(target=main, args=(b,bitrates[b]) )
    #     p.start()
    #     processes.append(p)

    #for p in processes:
    #     p.join()

    with multiprocessing.Pool(4) as pool:
        pool.starmap(main,p_args)
    #main("7000","1920:1080")
    #main("9000","2560:1440")
            
    
