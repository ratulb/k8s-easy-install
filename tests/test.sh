. utils.sh

num=$(echo $((1 + $RANDOM % 10)))
_lb=''
run_count=20
if [ ! -z "$1" ]; then
  run_count=$1
fi

count=0
while [[ $count -lt $run_count ]]; do
  if [ $num -lt 3 ]; then
    _lb=haproxy
  elif [[ $num -ge 3 ]] && [[ $num -le 6 ]]; then
    _lb=envoy
  else
    _lb=nginx
  fi
  sed -i "s/lb_type=.*/lb_type=$_lb/go" setup.conf
  prnt "lb is: $_lb"
  echo "lb is: $_lb" >>tests/test-result.txt

  echo 'y' | . launch-cluster.sh

  kubectl get nodes >>tests/test-result.txt
  sleep 30
  ((count++))
  num=$(echo $((1 + $RANDOM % 10)))
done
