ARG VERSION="4.4.1"


FROM wazuh/wazuh-manager:${VERSION} AS wazuh-manager
FROM hairyhenderson/gomplate:v3.11.5-slim AS gomplate
FROM mikefarah/yq:4.33.3 AS yq



FROM golang:1.20.4-bullseye AS multirun

WORKDIR /src
RUN wget -c https://github.com/nicolas-van/multirun/releases/download/1.1.3/multirun-x86_64-linux-gnu-1.1.3.tar.gz -O - | tar -xz


FROM golang:1.20.4-bullseye AS fsnotify
WORKDIR /src
RUN git clone https://github.com/fsnotify/fsnotify
RUN cd fsnotify/cmd/fsnotify \
  && GOOS=linux go build -tags release -a -ldflags "-extldflags -static" -o fsnotify



FROM bitnami/minideb:bullseye

ARG VERSION
ARG VERSION_REVISION="1"
RUN install_packages \
        curl \
        apt-transport-https \
        gnupg2 \
        rsync \
        inotify-tools \
        ca-certificates \
        net-tools \
        procps \
    # install wazuh
    && curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - \
    && echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list \
    && install_packages wazuh-agent=${VERSION}-${VERSION_REVISION}

COPY --from=wazuh-manager /var/ossec/ruleset/sca/ /var/ossec/ruleset/sca/
COPY --from=gomplate /gomplate /usr/bin/gomplate
COPY --from=multirun /src/multirun /var/ossec/bin/multirun
COPY --from=fsnotify /src/fsnotify/cmd/fsnotify/fsnotify /var/ossec/bin/fsnotify

COPY entrypoint.sh /entrypoint.sh 
COPY entrypoint-chroot.sh /var/ossec/bin/entrypoint-chroot.sh
COPY wazuh-control.sh /var/ossec/bin/wazuh-control.sh
COPY wazuh-tail-logs.sh /var/ossec/bin/wazuh-tail-logs.sh
COPY supervisord.conf /var/ossec/etc/supervisord.conf
COPY ossec.tpl.conf /var/ossec/etc/ossec.tpl.conf
RUN chmod +x /entrypoint.sh \
  && find /var/ossec/ruleset/sca/ -name "*.yml" -exec mv {} {}.disabled \; \
  && mv /var/ossec/ruleset/sca /var/ossec/ruleset/sca.bak

ENV WAZUH_MANAGER_ADDRESS=127.0.0.1
ENV WAZUH_MANAGER_PORT=1514
ENV WAZUH_MANAGER_ENROLLMENT_PORT=1515
ENV WAZUH_AGENT_NAME=agent
ENV WAZUH_AGENT_HOST_DIR=/host

ENTRYPOINT ["/entrypoint.sh"]