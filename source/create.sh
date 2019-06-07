for i in {1..5}; do
    kubectl apply -f example-${i}.yaml
done
