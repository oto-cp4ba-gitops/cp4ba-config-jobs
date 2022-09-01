#!/bin/bash
echo "started"
NAMESPACE=output-info
CONFIGMAP_NAME=cp4ba-postdeploy-md
TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount
CACERT=${TOKEN_PATH}/ca.crt

#set -e 

source ./postdeploy_venv/bin/activate

# Python here?
python_version=$(python -V 2>&1)
if [ $? -gt 0 ]; then
    echo "$0: python not found in PATH"
    exit 1
else
    if [ "${python_version#Python 3}" == "${python_version}" ]; then
        echo "$0: python in path is not on required version 3.x"
        exit 1
    fi
fi

# Check for required files to start with, i.e.,
# jinja2 template and the python/jinja2 script
for f in templates/postdeploy-output-info.md.j2 jinja_fill.py; do
    if [ ! -e $f ]; then
        echo "$0: Missing file '$f'"
        exit 1
    fi
done

# Log in to cluster:
oc_token=$(cat ${TOKEN_PATH}/token)
oc_server='https://kubernetes.default.svc'
oc login $oc_server --token=${oc_token} --certificate-authority=${CACERT} --kubeconfig="/tmp/config"

# Craft the command line, based on these optional bits:
jinja_fill_command="python jinja_fill.py"
# Which optional components are enabled?
sc_optional_components=$(oc get ICP4ACluster icp4adeploy -n cp4ba -o jsonpath="{$.spec.shared_configuration.sc_optional_components}")
sc_deployment_patterns=$(oc get ICP4ACluster icp4adeploy -n cp4ba -o jsonpath="{$.spec.shared_configuration.sc_deployment_patterns}")
[ "x${sc_optional_components}" != "x" ] && jinja_fill_command+=" -c ${sc_optional_components}"
[ "x${sc_deployment_patterns}" != "x" ] && jinja_fill_command+=" -p ${sc_deployment_patterns}"

# Generate postdeploy.md (default output filename):
${jinja_fill_command} -o /tmp/postdeploy.md
if [ $? -gt 0 ]; then
    echo "$0: $runout"
    exit 1
fi
# If exitcode is zero, show stdout. It should report success.
echo $runout
# Create the configmap yaml with the empty postdeploy.md object:
cat <<EOF > /tmp/postdeploy_configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cp4ba-postdeploy-md
  namespace: output-info
  finalizers:
    - argoproj.io/finalizer
immutable: true
data:
  postdeploy.md: |-
EOF
# jinja_fill command above should have already prepared the file postdeploy.md.
# Append that to the empty data object in the configmap yaml, indented properly:
cat /tmp/postdeploy.md | sed 's/^/    /' >> /tmp/postdeploy_configmap.yaml

# Just in case it already exists in the cluster, remove it first, after clearing finalizers:
check_cm=$(oc get configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} -o jsonpath="{$.metadata.name}" --ignore-not-found)
if [ ${check_cm}x == ${CONFIGMAP_NAME}x ]; then
       oc patch configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} --type merge -p'{ "metadata": { "finalizers" : [] }}'
       oc delete configmap ${CONFIGMAP_NAME} -n ${NAMESPACE}
fi
echo "posting postdeploy markdown as configmap."
oc create -f /tmp/postdeploy_configmap.yaml
