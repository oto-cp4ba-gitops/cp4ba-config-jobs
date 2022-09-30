FROM quay.io/openshift/origin-cli:v3.11.0
WORKDIR ~
COPY cm.yaml /tmp/cm.yaml
COPY predeploy.sh predeploy.sh
RUN chmod a+x predeploy.sh
CMD ["./predeploy.sh"]
