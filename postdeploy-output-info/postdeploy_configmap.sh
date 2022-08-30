#!/bin/bash
echo "started"
NAMESPACE=output-info
CONFIGMAP_NAME=cp4ba-postdeploy-md
TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount
CACERT=${TOKEN_PATH}/ca.crt

#set -e 

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
# jinja2 template, python/jinja2 script, and the configmap yaml:
for f in templates/postdeploy-output-info.md.j2 jinja_fill.py postdeploy_configmap.yaml; do
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
${jinja_fill_command}
if [ $? -gt 0 ]; then
    echo "$0: $runout"
    exit 1
fi
# If exitcode is zero, show stdout. It should report success.
echo $runout
# At this point, postdeploy.md should be ready. Append to empty data, indented properly:
cat postdeploy.md | sed 's/^/    /' >> postdeploy_configmap.yaml

# Just in case it already exists in the cluster, remove it first:
oc delete configmap ${CONFIGMAP_NAME} -n ${NAMESPACE}
echo "posting postdeploy markdown as configmap."
oc create -f postdeploy_configmap.yaml
