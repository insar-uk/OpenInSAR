myGithubUsernameFile=~/GithubUsername
myPatFile=~/PAT.txt

Username=$(<$myGithubUsernameFile)
PAT=$(<$myPatFile)
cd ~/../ephemeral
rm -f -r OpenInSAR
git clone https://$Username:$PAT@github.com/insar-uk/OpenInSAR_internal.git
cd OpenInSAR

chmod +x ICL_HPC/LAUNCHER.sh
./ICL_HPC/LAUNCHER.sh

cp update.sh ~/update.sh
chmod +x ~/update.sh