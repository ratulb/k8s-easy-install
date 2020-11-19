#Execute remote command
echo "Hostname followed by file containing commands"
ssh -o "StrictHostKeyChecking no" $1 < $2
