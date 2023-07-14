#!/bin/bash
runPath=$1;

if [ -z "$runPath" ]; then
    # exit
    echo "No runPath specified. You should run this from the OpenInSAR repository root."
	runPath=$(pwd)
fi

# Distinguish worker using array index
J=$PBS_ARRAY_INDEX
# if J is not defined, set it to 0
if [ -z "$J" ]; then
    J=0
    nJ=$J
fi

# module avail matlab
# load matlab onto cluster
module -s load 'matlab/R2021a' #silent mode suppresses nuisance 'error' about requirement

# find the script directory, go $HOME (tilde '~') then one up ('..'), then navigate to your ICSar script folder
cd $runPath

# confirm this
echo $runPath
cd $runPath
echo -e "Directory we start in is: $(pwd)"
echo "Num workers: $nJ"

# start matlab
echo "the time is: $(date), starting Matlab"

matlab -nodesktop -nosplash -noFigureWindows -r "J=$J; nJ=$nJ; leader;"
cd ..
echo "Matlab finished execution at: $(date)\n"
echo "End of shell script."
