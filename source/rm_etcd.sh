if [ "$1" == "" ]; then
  echo "Usage: rm_etcd.sh <aNum>"
  exit 1
fi
num=$1
NAME="etcd-decap"
echo "Removing ${NAME}-${num} ..."
echo ""

set -x

# Get the pod name that we want to be deleted.
#
count=$(kubectl get po | grep ${NAME}-${num} | wc -l)
if [ $count -eq 0 ]; then
    echo "${NAME}-${num} pod is already gone"
fi

# Get the image using the first running pod.
#
m1=$(kubectl get po | grep ${NAME} | grep Running| sed -n 1p | awk {'print $1'})
IMAGE=$(kubectl get po $m1 --output='jsonpath={.spec.containers[0].image}')

the_id=$(kubectl exec $m1 -- etcdctl member list| grep ${NAME}${num} | awk '{print $1}' | sed 's/://g')
kubectl exec  $m1 -- etcdctl member remove $the_id

cat ${NAME}-deployment.yaml | \
    sed "s#{{ etcd_num }}#$num#g" |
    sed "s#{{ etcd_image }}#$IMAGE#g" |
    sed "s#{{ etcd_member_list }}#$ETCD_INITIAL_CLUSTER#g" |
    sed "s#new#$ETCD_INITIAL_CLUSTER_STATE#g" > tmp_out

kubectl delete -f tmp_out

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

for i in {1..10}; do
    kubectl exec  $m1 -- etcdctl cluster-health > final-health.tmp
    count=$(cat final-health.tmp | grep "cluster is healthy" | wc -l)
    if [ $count -ne 0 ]; then
        echo "${NAME} cluster looks healthy"
        echo ""
        cat final-health.tmp
        break
    else
        echo "Waiting for ${NAME} cluster to be healthy"
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
