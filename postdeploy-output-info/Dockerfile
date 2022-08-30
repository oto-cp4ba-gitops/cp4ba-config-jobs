FROM quay.io/openshift/origin-cli:latest
LABEL description="postdeploy-configmap"
MAINTAINER Jeff Tan <jeffetan@au1.ibm.com>
ENV WORKER_HOME=/home/worker
RUN groupadd -r worker -f -g 1001 && \
    useradd -u 1001 -r -g worker -m -d ${WORKER_HOME} -s /sbin/nologin \
    -c "Worker User" worker && \
    chown -R worker:worker ${WORKER_HOME} && \
    chmod -R 755 ${WORKER_HOME} && \
    echo "[ -e ~/postdeploy_venv/bin/activate ] && . ~/postdeploy_venv/bin/activate" >> ${WORKER_HOME}/.bashrc
WORKDIR $WORKER_HOME
USER worker
RUN python -m venv postdeploy_venv && \
    . postdeploy_venv/bin/activate && \
    python -m pip install jinja2
# Source jinja file to populate with values:
COPY ./templates/ $WORKER_HOME/templates/
# Python script to render jinja2:
COPY ./jinja_fill.py jinja_fill.py
# Script to generate the markdown file, log in to cluster,
# append the markdown into the the configmap yaml, and create the configmap.
COPY ./postdeploy_configmap.sh postdeploy_configmap.sh
ENTRYPOINT ["/bin/bash", "postdeploy_configmap.sh"]
