 #TODO: RIPPED from the upstream kube test shell library. Everyone will need
 # this. What do we do?
 readonly reset=$(tput sgr0)
 readonly  bold=$(tput bold)
 readonly black=$(tput setaf 0)
 readonly   red=$(tput setaf 1)
 readonly green=$(tput setaf 2)

 # TODO: change to the right thing once this is working
 kubectl=${KUBECTL:-"oc"}

test::object_assert() {
  local tries=$1
  local object=$2
  local request=$3
  local expected=$4
  local args=${5:-}

  for j in $(seq 1 ${tries}); do
    res=$(eval $kubectl get ${args} ${object} -o jsonpath=\"${request}\")
    if [[ "${res}" =~ ^$expected$ ]]; then
      echo -n "${green}"
      echo "Successful get ${object} ${request}: ${res}"
      echo -n "${reset}"
      return 0
    fi
      echo "Waiting for Get ${object} ${request} ${args}: expected: ${expected}, got: ${res}"
      sleep $((${j}-1))
    done

    echo "${bold}${red}"
    echo "FAIL!"
    echo "Get ${object} ${request}"
    echo "  Expected: ${expected}"
    echo "  Got:      ${res}"
    echo "${reset}${red}"
    caller
    echo "${reset}"
    return 1
}

dir=$(realpath "$(dirname "${BASH_SOURCE}")/..")
cd $dir

# Create SVC Cat Stuff

cat << EOF | oc create -f -
apiVersion: operator.openshift.io/v1
kind: ServiceCatalogAPIServer
metadata:
  name: cluster
spec:
  logLevel: "Normal"
  managementState: Managed
EOF

cat <<EOF | oc create -f -
apiVersion: operator.openshift.io/v1
kind: ServiceCatalogControllerManager
metadata:
  name: cluster
spec:
  logLevel: "Normal"
  managementState: Managed
EOF


# wait for svc cat to be successful


oc new-project tsbo-test

# create crds
oc create -f deploy/crds/osb_v1alpha1_templateservicebroker_crd.yaml

# TSBO Image Format to test
echo "IMAGE_FORMAT=$IMAGE_FORMAT"
component_tsbo="template-service-broker-operator"
pipeline_tsbo_image=${IMAGE_FORMAT/\$\{component_tsbo\}/$component_tsbo}

echo "IMAGE_FORMAT=$IMAGE_FORMAT"
component_tsb="template-service-broker"
pipeline_tsb_image=${IMAGE_FORMAT/\$\{component_tsb\}/$component_tsb}

sed "s,REPLACE_IMAGE,$pipeline_tsbo_image," -i deploy/operator.yaml
sed "s,REPLACE_IMAGE,$pipeline_tsb_image," -i deploy/operator.yaml
sed "s,REPLACE_NAMESPACE,tsbo-test," -i deploy/operator.yaml
oc create -f deploy/operator.yaml

sed "s,REPLACE_NAMESPACE,tsbo-test," -i deploy/role.yaml
oc create -f deploy/role.yaml

sed "s,REPLACE_NAMESPACE,tsbo-test," -i deploy/service_account.yaml
oc create -f deploy/service_account.yaml

sed "s,REPLACE_NAMESPACE,tsbo-test," -i deploy/crds/osb_v1alpha1_templateservicebroker_cr.yaml
oc create -f deploy/crds/osb_v1alpha1_templateservicebroker_cr.yaml

# wait until successfull  reconcile

# wait until Cluster Service Broker is fetched.
