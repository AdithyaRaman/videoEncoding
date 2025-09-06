#!/bin/bash

 python encode.py -i ~/inter4k/low_comp.mp4 -c h264 -o low -f 60 -v low > stdout/low.out 
 python encode.py -i ~/inter4k/lowmed_comp.mp4 -c h264 -o lowmed -f 60 -v low > stdout/lowmed.out 
 python encode.py -i ~/inter4k/med_comp.mp4 -c h264 -o med -f 60 -v low > stdout/med.out 
 python encode.py -i ~/inter4k/medhigh_comp.mp4 -c h264 -o medhigh -f 60 -v low > stdout/medhigh.out 
 python encode.py -i ~/inter4k/high_comp.mp4 -c h264 -o high -f 60 -v low > stdout/high.out 
