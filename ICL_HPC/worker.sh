#!/bin/bash

if [ -z "$runPath" ]; then
    # exit
    echo "No runPath specified"
	runPath=~/OpenInSAR/
    echo "Setting runPath to $runPath"
fi

# Distinguish worker using array index
J=$PBS_ARRAY_INDEX
# if J is not defined, set it to 42
if [ -z "$J" ]; then
    J=42
    nJ=$J
fi

# module avail matlab
# load matlab onto cluster
module load fix_unwritable_tmp # preload requirement to avoid warning
module load matlab/R2021a

# find the script directory, go $HOME (tilde '~') then one up ('..'), then navigate to your ICSar script folder
cd $runPath

# confirm this
echo $runPath
cd $runPath
echo -e "Directory we start in is: $(pwd)"
echo "Num workers: $nJ"

# start matlab
echo "the time is: $(date), starting Matlab"
pwd
matlab -nodesktop -nosplash -noFigureWindows -r "disp('Matlab is in:'); pwd; J=$J; nJ=$nJ; addpath('ICL_HPC'); worker;"
cd ..
echo "Matlab finished execution at: $(date)\n"
echo "End of shell script."
