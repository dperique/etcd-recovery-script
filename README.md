# A simple etcd recovery script (for Kubernetes)

This script is used to recover restarted etcd members in an etcd cluster that resides
on a Kubernetes cluster.  It can recover one etcd member or multiple.

It is meant for rudimentary recovery via bash scripting.  If you want something that
does more, I recommend [etcd-operator](https://github.com/coreos/etcd-operator).  I created
this because I wanted to manage an etcd cluster that was created by my team and with our
own customizations that were not supported by etcd-operator.

My assumption is that you have this in the case of a five member etcd cluster on
Kubernetes:

* Each etcd member is a Pod controlled by a Deployment template
* The Deployments create etcd member Pods using name=NAME-N (where NAME is some string
  and N is a number from 1..5)
  * for example, all etcd member Pods have a name like "example-N-xxxxx" where
    N=1..5.  This allows the script to reference which etcd member to recover
* You start out with a running five member etcd cluster built using this template
* Your k8s cluster/context is setup so you can do a `kubectl exec -ti` to
  any etcd member Pod
* The etcd member Pods use ephemeral storage (i.e., when they restart, their
  data is wiped)
  * If you use persistent volumes, you will have to modify the script to wipe
    the data.  But if you use persistent volumes, when an etcd member is restarted,
    it most likely will not need recovery

## Create the sample example 5 member etcd cluster

First get a Kubernetes cluster and set context to it -- minikube might be good enough.

In the source subdir, run `generate.sh` to create yamls for a 5 member etcd cluster
and then apply them to your Kubernetes cluster like this:

```
cd source
./generate.sh
for i in {1..5}; do
  kubectl apply -f example-${i}.yaml
done
```

In a few seconds, your 5 member cluster should be up.

```
$ m1=$(kubectl get po | grep example-1 | head -1 | awk '{print $1}' )

$ kubectl exec $m1 -- etcdctl cluster-health

member 10cd19f5dff12f8 is healthy: got healthy result from http://example1:2379
member 9a0306eb09f471b8 is healthy: got healthy result from http://example4:2379
member c46fc1decca979cd is healthy: got healthy result from http://example3:2379
member eea200154b9a0634 is healthy: got healthy result from http://example5:2379
member fc3480c8386a1759 is healthy: got healthy result from http://example2:2379
cluster is healthy
```

## Delete an etcd member to get it to crashloop

Now, let's simulate that an etcd member was restarted and hence goes into crashLoop mode.

```
$ m1=$(kubectl get po | grep example-3 | head -1 | awk '{print $1}' )
$ kubectl delete po $m1
pod "example-3-7c5f7d6568-2ts8j" deleted

$ kubectl get po |grep example
example-1-6894c55b77-xl9x7          1/1       Running            0          46m
example-2-55c9bbfd69-lmr7p          1/1       Running            0          8m42s
example-3-7c5f7d6568-9m9sr          0/1       CrashLoopBackOff   1          8s
example-4-6d57b4ddd5-6whb6          1/1       Running            0          7m52s
example-5-8499f5cf6-pg7vr           1/1       Running            0          39m
```

This etcd member will keep crashing because its data was wiped and cannot automatically
rejoin the etcd cluster.

## Recover the bad etcd member

First wait until there is only one pod show that is in crashLoop or Error status.

Now recover the bad etcd member using the `etcd_recover.sh` script.

```
$ ./etcd_recover.sh 3
Recovering example-3 ...

deployment.extensions "example-3" deleted
Sleeping ...
example-3 pod is still there
Sleeping ...
example-3 pod is gone
command terminated with exit code 5
Removed member ad98a0c387da7c51 from cluster
deployment.extensions/example-3 created
service/example3 unchanged
Sleeping ...
New example-3 pod is up
Wait a few seconds for it to join the etcd cluster
example cluster looks healthy

member 77ea975eb4b84593 is healthy: got healthy result from http://example1:2379
member 7bd01ce9ee688b3d is healthy: got healthy result from http://example4:2379
member 8d3c1cf8da8d6c10 is healthy: got healthy result from http://example5:2379
member 9829e40af3acd3a7 is healthy: got healthy result from http://example2:2379
member dd07c8286f88e272 is healthy: got healthy result from http://example3:2379
cluster is healthy

Done.
```

From the final output, you can see the cluster is in good health.

## Delete two etcd members to get them to crashloop

Now, let's simulate that more than one etcd member was restarted and hence goes into crashLoop mode.

```
$ m1=$(kubectl get po | grep example-2 | head -1 | awk '{print $1}' )
$ kubectl delete po $m1
pod "example-2-55c9bbfd69-lmr7p" deleted

$ m1=$(kubectl get po | grep example-4 | head -1 | awk '{print $1}' )
$ kubectl delete po $m1
pod "example-4-6d57b4ddd5-6whb6" deleted

$ kubectl get po|grep example
example-1-6894c55b77-xl9x7          1/1       Running            0          63m
example-2-55c9bbfd69-9kqbs          0/1       CrashLoopBackOff   2          32s
example-3-858bb47f4c-nfcbd          1/1       Running            0          14m
example-4-6d57b4ddd5-wcvv5          0/1       CrashLoopBackOff   1          15s
example-5-8499f5cf6-pg7vr           1/1       Running            0          55m
```

For the two etcd member case, you recover them one at a time.  Also note that the
recover script removes all bad members before adding one back.

Recover etcd member 2:

```
$ ./etcd_recover.sh 2
Recovering example-2 ...

deployment.extensions "example-2" deleted
Sleeping ...
example-2 pod is still there
Sleeping ...
example-2 pod is still there
Sleeping ...
example-2 pod is still there
Sleeping ...
example-2 pod is still there
Sleeping ...
example-2 pod is gone
command terminated with exit code 5
Removed member 7bd01ce9ee688b3d from cluster
Removed member 9829e40af3acd3a7 from cluster
deployment.extensions/example-2 created
service/example2 unchanged
Sleeping ...
New example-2 pod is up
Wait a few seconds for it to join the etcd cluster
example cluster looks healthy

member 3ffcfdf2e37b4847 is healthy: got healthy result from http://example2:2379
member 77ea975eb4b84593 is healthy: got healthy result from http://example1:2379
member 8d3c1cf8da8d6c10 is healthy: got healthy result from http://example5:2379
member dd07c8286f88e272 is healthy: got healthy result from http://example3:2379
cluster is healthy

Done.
```

Note that member 4 is still missing.

Now recover member 4:

```
$ ./etcd_recover.sh 4
Recovering example-4 ...

deployment.extensions "example-4" deleted
Sleeping ...
example-4 pod is still there
Sleeping ...
example-4 pod is gone
Using alternate bad id search method
bad_id is wrong
It's because the bad member 4 is already gone; continuing ...
deployment.extensions/example-4 created
service/example4 unchanged
Sleeping ...
New example-4 pod is up
Wait a few seconds for it to join the etcd cluster
example cluster looks healthy

member 2b2feaa293d31a14 is healthy: got healthy result from http://example4:2379
member 3ffcfdf2e37b4847 is healthy: got healthy result from http://example2:2379
member 77ea975eb4b84593 is healthy: got healthy result from http://example1:2379
member 8d3c1cf8da8d6c10 is healthy: got healthy result from http://example5:2379
member dd07c8286f88e272 is healthy: got healthy result from http://example3:2379
cluster is healthy

Done.
```

Note all members are present and the etcd cluster is in good health.

## Test cases

* Individual etcd members restart (see source/tests/single.sh)
* Two etcd members restart, test all combinations (see source tests/multiple.sh)
  * Try all combinations via tweaking the script as mentioned in the comment
  * todo: make more scripts so you don't have to tweak
  * todo: when deleting a member, keep deleting it until it's gone and not just
    "running but not part of the cluster"

* Attempt to recover a health etcd member
  * Script aborts saying it's already healthy.

* any two etcd members restart
  * etcd_recovery.sh (any of the bad ones)
  * etcd_recovery.sh (the other bad one)

* recover when pod already gone
  * script realizes it's gone and moves on with recovery

* two members restarted and we manually delete them from member list
  * script realizes bad members are gone and moves on with recovery

* member in Running state yet not part of cluster; you run `etcdctl cluster-health`
  and see member is not there
  * delete that pod, wait for it to be gone
  * etcd_recovery.sh (num)
  * todo: check cluster-health and search for this number, if not there, recover it
    even though it's already in Running state

* first etcd pod in Running state is not part of the cluster
  * todo: since we use the first Running pod as the one to do cluster health check
    and remove/add member, first ensure it's part of the cluster.  If not, move to
    next Running pod.

## List of files

* create.sh: script to create the example etcd cluster from the generated yamls
* destroy.sh: script to fully destroy the example etcd cluster from the generated yamls
* etcd_recover.sh: the recovery script
* example-deployment.yaml: the template for the example etcd cluster
* example-deployment-new.yaml: the same template except for initial etcd cluster
* generate.sh: generate the yamls for a 5 pod etcd cluster
* test/single.sh: test recovery of single restarted etcd members
* test/multiple.sh: test recovery of multiple restarted etcd members
