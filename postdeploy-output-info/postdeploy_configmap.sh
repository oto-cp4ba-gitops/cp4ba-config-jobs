#!/bin/bash
echo "started"
NAMESPACE=output-info
CONFIGMAP_NAME=cp4ba-postdeploy-md
TOKEN_PATH=/var/run/secrets/kubernetes.io/serviceaccount
CACERT=${TOKEN_PATH}/ca.crt

#set -e 

which python3 2> /dev/null >&2
if [ $? -gt 0 ]; then
    echo "$0: Required python3 not found in PATH"
    exit 1
fi

# To customize the rendering, update this python script,
# making sure that the j2 and markdown file names match with this script:
runout=$(python3 jinja_fill.py 2>&1)
if [ $? -gt 0 ]; then
    echo "$0: $runout"
    exit 1
fi
# If exitcode is zero, show stdout.
echo $runout

# Check for required files, including generated one, being here
# (jinja2 template, python3 script, configmap yaml and the generated markdown file):
for f in postdeploy-output-info.md.j2 jinja_fill.py postdeploy_configmap.yaml postdeploy.md; do
    if [ ! -e $f ]; then
        echo "$0: Missing file '$f'"
        exit 1
    fi
done

oc_token=$(cat ${TOKEN_PATH}/token)
oc_server='https://kubernetes.default.svc'
oc login $oc_server --token=${oc_token} --certificate-authority=${CACERT} --kubeconfig="/tmp/config"
echo "Adding markdown to configmap."
cat postdeploy.md | sed 's/^/    /' >> postdeploy_configmap.yaml
# Just in case it already exists, remove it first:
runout=$(oc delete configmap ${CONFIGMAP_NAME} -n ${NAMESPACE} 2>&1)
echo "posting postdeploy markdown as configmap."
oc create -f postdeploy_configmap.yaml
