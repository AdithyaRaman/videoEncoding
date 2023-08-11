import os
import subprocess
import argparse

def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument('-i', '--inputFile', dest='inputFile', help='Source Input File',
    			default='/media/araman5/Adi/big_buck_bunny_1080p24.y4m', type=str)
    parser.add_argument('-r', '--resolution', dest='resolution', help='Resolution(Eg 1920:1080)',
    			default='1920:1080', type=str)
    parser.add_argument('-c', '--codec', dest='codec', help='Codec (Eg h264)',
    			default='h264', type=str)
    parser.add_argument('-b', '--bitrate', dest='bitrate', help='Bitrate (Eg 5800k)',
    			default='5800', type=str)
    parser.add_argument('-o','--outputFile', dest='outputFile', help='Output file',
    			default='test.mp4', type=str)
    parser.add_argument('-f', '--fps', dest='fps', help='Frame/Sec (Eg, 60)',
    			default="60", type=str)

    args = parser.parse_args()
    return args





if __name__ == "__main__" :

    videoTitle = "bbb_24fps"
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
    
    ARGS = parse_args()
    bitrates = {
                "375":"384:288",
                "560":"512:384",
                "750":"512:384",
                "1050":"640:480",
                "1750":"720:480",
                "2350":"1280:720",
                "3000":"1280:720",
                "4300":"1920:1080",
                "5800":"1920:1080"
    }

    for b,r in bitrates.items():
        
        maxRate = f"{b}k"
        bufSize = maxRate
        keyInt = int(ARGS.fps)*2
        keyIntMin = int(ARGS.fps)*2
        fileName = ARGS.inputFile.split("/")[-1]
        outputFile = f"{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.mp4"
        """
        FFMPEG Encoding
        """
        cmdFfmpeg = f"ffmpeg -i {ARGS.inputFile} -vf scale={r} -vcodec {ARGS.codec} -b:v {b}k -c:v libx264 -r {ARGS.fps} -minrate {maxRate} -maxrate {maxRate} -bufsize {bufSize} -g {keyInt} -keyint_min {keyIntMin}  -sc_threshold 0 -x264opts 'no-scenecut'  -an {dirName}/{outputFile} "
        
    
        # Start the encoding process
        os.system(cmdFfmpeg)

        """
	Segmenting using MP4Box
	"""
        # Start the Segmenting process
        manifest_path = f"{manifestDir}/{fileName[:-4]}-{b}k-{r.replace(':','x',1)}.mpd"
        cmdMp4box = f"MP4Box -dash {1000} -rap -profile dashavc264:live -mpd-title {videoTitle} -out {manifest_path} -segment-name segments/dash_{b}k_%s_ -frag {1000} {dirName}/{outputFile}"

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

        os.system(cmdQuality)
        #break

        

    
