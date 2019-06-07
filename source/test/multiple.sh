# Run through all five members, delete two, and recover it.
# When done, you should have a five member etcd cluster in good health.
#
MAX=10
NAME=example

# Tweak the code in for loop and the let num1 code to make it so we try all
# combinations: 1,2 2,3 3,4 4,5 5,1   1,3 2,4 3,5
for num in {1..3}; do
#for num in {3..3}; do
#for num in {1..1}; do

    # Delete an etcd member pod.
    m1=$(kubectl get po | grep ${NAME}-${num} | awk {'print $1'})
    kubectl delete po $m1

    let num1="$num + 2"
    m1=$(kubectl get po | grep ${NAME}-${num1} | awk {'print $1'})
    kubectl delete po $m1

    # Wait for pod to not be in Running state.
    for i in `seq 1 $MAX` ; do

        echo "Sleeping ..."
        sleep 2
        count=$(kubectl get po| grep ${NAME}-${num} | grep Running | wc -l)
        if [ $count -eq 0 ]; then
            echo "${NAME}-${num} pod is no longer in Running state"
            count=$(kubectl get po| grep ${NAME}-${num1} | grep Running | wc -l)
            if [ $count -eq 0 ]; then
                echo "${NAME}-${num1} pod is no longer in Running state"
                break
            else
                echo "${NAME}-${num1} pod is still in Running state"
            fi
        else
            echo "${NAME}-${num} pod is still in Running state"
        fi
    done

    if [ $i -eq $MAX ]; then
        echo "${NAME}-${num} and ${NAME}-${num1} took too long to get out of Running state; aborting..."
        exit 1
    fi

    echo "Testcase begin : Recover etcd members $num, $num1 ****************************************"
    ./etcd_recover.sh $num
    if [ $? -eq 0 ]; then
        echo "PASS : Recover etcd members $num ****************"
    else
        echo "FAIL : Recover etcd members $num ****************"
        exit 1
    fi
    ./etcd_recover.sh $num1
    if [ $? -eq 0 ]; then
        echo "PASS : Recover etcd members $num1 ****************"
    else
        echo "FAIL : Recover etcd members $num1 ****************"
        exit 1
    fi
done
exit 0
