runPath=$(realpath $(pwd))
scriptPath=$(realpath $(pwd))
nCpus=4;
nJ=${1:-99} # use first arg or default to 99
nMem=16;
nHour=3;
nMin=55;

matScript='worker'
pwd
echo "Launching workers"
date
echo $(pwd)
qsub -lselect=1:ncpus=$nCpus:mem=$[nMem]gb -lwalltime=$nHour:$nMin:00 -J 1-$nJ -v runPath=$runPath,scriptPath=$scriptPath,nCpus=$nCpus,nJ=$nJ,matScript=$matScript ICL_HPC/worker.sh
