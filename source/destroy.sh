for i in {1..5}; do
    kubectl delete -f example-${i}.yaml
done
