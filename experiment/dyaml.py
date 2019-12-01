"""
My goal here was to make it so that I can do the substitution for
the --initial-cluster and --initial-cluster-state without having to
have the original deployment yaml present.

This had some problems:
  * the two ETCD* variables needed an "export" in front of them
  * I did not figure out how to kubectl patch deployment example-1 -p aFile.out

See: https://stackoverflow.com/questions/29518833/editing-yaml-file-by-python
  for where I found ruamel.
"""
import sys
import ruamel.yaml

yaml = ruamel.yaml.YAML()
with open('new.out') as fp:
    data = yaml.load(fp)

# ruamel creates an interesting nested structure with the yaml file so
# "walk" it accordingly to find the two places you need to modify.
# This code is highly dependent on how the original yaml was created.
#
for i in range(len(data['spec']['template']['spec']['containers'][0]['command'])):
    if data['spec']['template']['spec']['containers'][0]['command'][i] == "--initial-cluster":
      init_cluster = i + 1
      break
    if data['spec']['template']['spec']['containers'][0]['command'][i] == --initial-cluster-state":
      init_cluster_state = i + 1
      break

# Before runnign this script, ensure ETCD_INITIAL_CLUSTER and ETCD_INITIAL_CLUSTER_STATE
# are defined.
#
data['spec']['template']['spec']['containers'][0]['command'][init_cluster] = os.getenv('ETCD_INITIAL_CLUSTER')
data['spec']['template']['spec']['containers'][0]['command'][init_cluster_state] = os.genenv('ETCD_INITIAL_CLUSTER_STATE')

yaml.dump(data, sys.stdout)
