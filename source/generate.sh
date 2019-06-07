NAME="example"
IMAGE="quay.io/coreos/etcd:v3.3.8"
ETCD_INITIAL_CLUSTER="example1=http://example1:2380,etcd-decap2=http://etcd-decap2:2380,etcd-decap3=http://etcd-decap3:2380,etcd-decap4=http://etcd-decap4:2380,etcd-decap5=http://etcd-decap5:2380"
ETCD_INITIAL_CLUSTER_STATE="new"

for num in 1 2 3 4 5 ; do
    cat ${NAME}-deployment-new.yaml | \
        sed "s#{{ etcd_num }}#$num#g" |
        sed "s#{{ etcd_image }}#$IMAGE#g" |
        sed "s#{{ etcd_member_list }}#$ETCD_INITIAL_CLUSTER#g" |
        sed "s#new#$ETCD_INITIAL_CLUSTER_STATE#g" > example-${num}.yaml
done


