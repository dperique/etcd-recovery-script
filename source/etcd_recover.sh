if [ "$1" == "" ]; then
  echo "Usage: etcd_recover.sh <aNum>"
  exit 1
fi
num=$1
NAME="example"
echo "Recovering ${NAME}-${num} ..."
echo ""

set +x

# Get the pod name that we want to be deleted.
#
count=$(kubectl get po | grep ${NAME}-${num} | head -1 | grep Running | wc -l)
if [ $count -eq 1 ]; then
    echo "${NAME}-${num} pod is in Running state; aborting ..."
    exit 1
fi
count=$(kubectl get po | grep ${NAME}-${num} | wc -l)
if [ $count -eq 0 ]; then
    echo "${NAME}-${num} pod is already gone"
fi

# Get the image using the first running pod.
#
m1=$(kubectl get po | grep ${NAME} | grep Running| sed -n 1p | awk {'print $1'})
IMAGE=$(kubectl get po $m1 --output='jsonpath={.spec.containers[0].image}')

t=$(kubectl get deployments | grep ${NAME}-${num} | wc -l)
if [ $t -ne 0 ]; then
    kubectl delete deployments ${NAME}-${num}
fi

# Wait up to 60 seconds for the pod to go away.
#
MAX=60
for i in `seq 1 $MAX` ; do
    echo "Sleeping ..."
    sleep 2
    count=$(kubectl get po| grep ${NAME}-${num} | wc -l)
    if [ $count -eq 0 ]; then
        echo "${NAME}-${num} pod is gone"
        break
    else
        echo "${NAME}-${num} pod is still there"
    fi
done
if [ $i -eq $MAX ]; then
    echo "${NAME}-${num} pod took too long to go away"
    exit 1
fi

# Uncomment this to see more debugging.
#set -x

# Add a new etcd member using the first Running ${NAME} pod.
#
m1=$(kubectl get po | grep ${NAME} | grep Running| sed -n 1p | awk {'print $1'})
kubectl exec  $m1 -- etcdctl cluster-health > cluster-health.tmp

ready=0
bad_id=$(cat cluster-health.tmp |grep "failed to check the health" | head -1 | awk '{print $8}')
if [[ $bad_id == "" ]]; then
    echo "Using alternate bad id search method"
    bad_id=$(cat cluster-health.tmp |grep "unreachable" | head -1 | awk '{print $2}')
else
    match_count=$(cat cluster-health.tmp | grep "failed to check the health" | wc -l)
    str="failed to check the health"
    ready=1
fi

if [ $ready -eq 0 ]; then
    if [[ $bad_id == "" ]]; then
        echo "No bad members present in member list"
        bad_count=$(cat cluster-health.tmp |grep -e "unreachable" -e "failed to check the health" | head -1 | wc -l)
        if [ $bad_count -eq 0 ]; then
            # No members to remove.
            echo "It's because the bad member $num is already gone; continuing ..."
            match_count=0
        else
            exit 1
        fi
    else
        match_count=$(cat cluster-health.tmp | grep "unreachable" | wc -l)
        bad_count=1
        str="unreachable"
    fi
fi

if [ $match_count -ne 0 ]; then
    # If there are multiple unreachable members, we must remove them all.
    for i in `seq 1 $match_count`; do
        if [[ $str == "unreachable" ]]; then
            the_id=$(cat cluster-health.tmp |grep -e "$str" | sed -n ${i}p | awk {'print $2'})
        else
            the_id=$(cat cluster-health.tmp |grep -e "$str" | sed -n ${i}p | awk {'print $8'})
        fi
        kubectl exec  $m1 -- etcdctl member remove $the_id
    done
fi
kubectl exec  $m1 -- etcdctl member add ${NAME}${num} http://${NAME}${num}:2380 | grep ETCD_INITIAL > tmp_out1
source tmp_out1

cat ${NAME}-deployment.yaml | \
    sed "s#{{ etcd_num }}#$num#g" |
    sed "s#{{ etcd_image }}#$IMAGE#g" |
    sed "s#{{ etcd_member_list }}#$ETCD_INITIAL_CLUSTER#g" |
    sed "s#new#$ETCD_INITIAL_CLUSTER_STATE#g" > tmp_out

kubectl apply -f tmp_out

# Wait up to 60 seconds for new pod to come up.
#
MAX=30
for i in `seq 1 $MAX` ; do
    echo "Sleeping ..."
    sleep 2
    count=$(kubectl get po| grep ${NAME}-${num} | grep Running | wc -l)
    if [ $count -ne 0 ]; then
        echo "New ${NAME}-${num} pod is up"
        echo "Wait a few seconds for it to join the etcd cluster"
        #sleep 5
        break
    else
        echo "${NAME}-${num} pod still not there"
    fi
done
if [ $i -eq $MAX ]; then
    echo "${NAME}-${num} pod took too long to come up"
    exit 1
fi

for i in {1..10}; do
    kubectl exec  $m1 -- etcdctl cluster-health > final-health.tmp
    count=$(cat final-health.tmp | grep "cluster is healthy" | wc -l)
    if [ $count -ne 0 ]; then
        echo "${NAME} cluster looks healthy"
        echo ""
        cat final-health.tmp
        break
    else
        "Waiting for ${NAME} cluster to be healthy"
        sleep 5
    fi
done

if [ $i -eq 10 ]; then
    echo "Error waiting for cluster to be in good health"
    exit 1
else
    echo ""
    echo "Done."
    exit 0
fi
