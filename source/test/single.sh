# Run through all five members, delete one, and recover it.
# When done, you should have a five member etcd cluster in good health.
#
MAX=60
NAME=example

for num in {1..5}; do

    # Delete an etcd member pod.
    #m1=$(kubectl get po | grep ${NAME}-${num} | sed -n ${n}p | awk {'print $1'})
    m1=$(kubectl get po | grep ${NAME}-${num} | awk {'print $1'})
    kubectl delete po $m1

    # Wait for pod to not be in Running state.
    for i in `seq 1 $MAX` ; do

        echo "Sleeping ..."
        sleep 2
        count=$(kubectl get po| grep ${NAME}-${num} | grep Running | wc -l)
        if [ $count -eq 0 ]; then
            echo "${NAME}-${num} pod is no longer in Running state"
            break
        else
            echo "${NAME}-${num} pod is still in Running state"
        fi
    done

    if [ $i -eq $MAX ]; then
        echo "${NAME}-${num} pod took too long to get out of Running state"
        exit 1
    fi

    echo "Testcase begin : Recover etcd member $num *******************************************"
    ./etcd_recover.sh $num
    if [ $? -eq 0 ]; then
        echo "PASS : Recover etcd members $num ****************"
    else
        echo "FAIL : Recover etcd members $num ****************"
        exit 1
    fi
    echo "Testcase end   : Recover etcd member $num ****************"
done
exit 0
