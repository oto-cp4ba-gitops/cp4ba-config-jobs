FROM registry.access.redhat.com/ubi9/ubi-minimal
WORKDIR ~
COPY postdeploy-config.sh postdeploy-config.sh
COPY services.sh services.sh
COPY ier/ierconfig.tar.gz /ierconfig/ierconfig.tar.gz
COPY ier/AdditionalJars.tar.gz ier/AdditionalJars.tar.gz
RUN chmod 777 -R /ierconfig
RUN chmod a+x postdeploy-config.sh
RUN chmod a+x services.sh
ENV JAVA_HOME=/etc/alternatives/jre
RUN microdnf update -y && microdnf install -y tar gzip jq java-11-openjdk wget && \
    wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.11.0/openshift-client-linux-4.11.0.tar.gz && \
    tar xzvf openshift-client-linux-4.11.0.tar.gz -C /usr/bin && rm openshift-client-linux-4.11.0.tar.gz && rm /usr/bin/README.md && \
    chmod +x /usr/bin/oc && chmod +x /usr/bin/kubectl && \
    # chmod +x /usr/bin/oc && \
    microdnf remove -y wget && microdnf clean all
    # wget https://mirror.openshift.com/pub/openshift-v3/clients/3.11.0-0.10.0/linux/oc.tar.gz && \
    # tar xzvf oc.tar.gz -C /usr/bin && rm oc.tar.gz &&  \
CMD ["./postdeploy-config.sh"]
