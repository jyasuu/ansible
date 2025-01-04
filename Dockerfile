# --------------------------------------------------------------------------------------------------
# Builder Image
# --------------------------------------------------------------------------------------------------
FROM alpine:3.16 AS builder

RUN set -eux \
    && apk add --update --no-cache \
        # build tools
        coreutils \
        g++ \
        gcc \
        make \
        musl-dev \
        openssl-dev \
        python3-dev \
        # misc tools
        bc \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        py3-pip \
        python3 \
# Fix: ansible --version: libyaml = True
# https://www.jeffgeerling.com/blog/2021/ansible-might-be-running-slow-if-libyaml-not-available
    && apk add --update --no-cache \
        py3-yaml \
    && python3 -c 'import _yaml'

# Pip required tools
RUN set -eux \
    && pip3 install --no-cache-dir --no-compile \
        wheel
RUN set -eux \
    && pip3 install --no-cache-dir --no-compile \
        Jinja2 \
        MarkupSafe \
        PyNaCl \
        bcrypt \
        cffi \
        cryptography \
        pycparser

ARG VERSION
RUN set -eux \
    && MAJOR_VERSION="$( echo "${VERSION}" | awk -F'.' '{print $1}' )" \
    && MINOR_VERSION="$( echo "${VERSION}" | awk -F'.' '{print $2}' )" \
    \
    && if [ "${VERSION}" = "latest" ]; then \
        pip3 install --no-cache-dir --no-compile ansible; \
    \
    elif [ "${MINOR_VERSION}" -lt "10" ]; then \
        pip3 install --no-cache-dir --no-binary pyyaml ansible~=${VERSION}.0; \
    \
    # Ansible added a weired versioning system with ansible-core and ansible packages:
    # https://docs.ansible.com/ansible/devel/reference_appendices/release_and_maintenance.html#ansible-community-changelogs
    elif [ "${VERSION}" = "2.10" ]; then\
        pip3 install --no-cache-dir --no-binary pyyaml ansible~=3.0; \
    \
    elif [ "${VERSION}" = "2.11" ]; then\
        pip3 install --no-cache-dir --no-binary pyyaml ansible~=4.0; \
    \
    elif [ "${VERSION}" = "2.12" ]; then\
        pip3 install --no-cache-dir --no-binary pyyaml ansible~=5.0; \
    \
    elif [ "${VERSION}" = "2.13" ]; then\
        pip3 install --no-cache-dir --no-binary pyyaml ansible~=6.0; \
    \
    else \
        fail; \
    fi \
    \
    && if [ "${VERSION}" != "latest" ]; then \
        ansible --version | grep ^ansible | grep -E "${VERSION}\.[0-9]+" \
        && ansible-playbook --version | grep ^ansible | grep -E "${VERSION}\.[0-9]+" \
        && ansible-galaxy --version | grep ^ansible | grep -E "${VERSION}\.[0-9]+"; \
    fi \
    \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# Python packages (copied to final image)
RUN set -eux \
    && pip3 install --no-cache-dir --no-compile \
        junit-xml \
        lxml \
        paramiko \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# Clean-up some site-packages to safe space
RUN set -eux \
    && pip3 uninstall --yes \
        setuptools \
        wheel \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf


    RUN set -eux \
    && apk add --update --no-cache \
        curl

# Python packages (copied to final image)
RUN set -eux \
    && if [ "${VERSION}" = "2.5" ]; then \
        pip3 install --no-cache-dir --no-compile dnspython mitogen==0.2.10; \
    elif [ "${VERSION}" = "2.6" ]; then \
        pip3 install --no-cache-dir --no-compile dnspython mitogen==0.2.10; \
    elif [ "${VERSION}" = "2.7" ]; then \
        pip3 install --no-cache-dir --no-compile dnspython mitogen==0.2.10; \
    elif [ "${VERSION}" = "2.8" ]; then \
        pip3 install --no-cache-dir --no-compile dnspython mitogen==0.2.10; \
    elif [ "${VERSION}" = "2.9" ]; then \
        pip3 install --no-cache-dir --no-compile dnspython mitogen==0.2.10; \
    else \
        pip3 install --no-cache-dir --no-compile dnspython mitogen; \
    fi \
    \
    && pip3 install --no-cache-dir --no-compile \
        jmespath \
    \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# Binaries (copied to final image)
RUN set -eux \
    && if [ "$(uname -m)" = "aarch64" ]; then \
        ARCH="arm64"; \
    elif [ "$(uname -m)" = "x86_64" ]; then \
        ARCH="amd64"; \
    else \
        fail; \
    fi \
    \
    && YQ="$( curl -L -sS --fail -o /dev/null -w %{url_effective} https://github.com/mikefarah/yq/releases/latest | sed 's/^.*\///g' )" \
    \
    && curl -L -sS --fail "https://github.com/mikefarah/yq/releases/download/${YQ}/yq_linux_${ARCH}" > /usr/bin/yq \
    && chmod +x /usr/bin/yq \
    \
    && yq --version


# --------------------------------------------------------------------------------------------------
# Final Image
# --------------------------------------------------------------------------------------------------
FROM alpine:3.16 AS production
ARG VERSION
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#LABEL "org.opencontainers.image.created"=""
#LABEL "org.opencontainers.image.version"=""
#LABEL "org.opencontainers.image.revision"=""
LABEL "maintainer"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.authors"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.vendor"="cytopia"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.url"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.documentation"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.source"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.ref.name"="Ansible ${VERSION} base"
LABEL "org.opencontainers.image.title"="Ansible ${VERSION} base"
LABEL "org.opencontainers.image.description"="Ansible ${VERSION} base"

RUN set -eux \
    && apk add --no-cache \
# Issue: #85 libgcc required for ansible-vault
        libgcc \
        py3-pip \
        python3 \
# Issue: #76 yaml required for 'libyaml = True' (faster startup time)
        yaml \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
    && find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf \
    \
    && ln -s /usr/bin/python3 /usr/bin/python

COPY --from=builder /usr/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/
COPY --from=builder /usr/bin/ansible* /usr/bin/

# Pre-compile Python for better performance
RUN set -eux \
    && python3 -m compileall -j 0 /usr/lib/python3.10

WORKDIR /data
CMD ["/bin/sh"]

ARG VERSION

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#LABEL "org.opencontainers.image.created"=""
#LABEL "org.opencontainers.image.version"=""
#LABEL "org.opencontainers.image.revision"=""
LABEL "maintainer"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.authors"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.vendor"="cytopia"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.url"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.documentation"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.source"="https://github.com/cytopia/docker-ansible"
LABEL "org.opencontainers.image.ref.name"="Ansible ${VERSION} tools"
LABEL "org.opencontainers.image.title"="Ansible ${VERSION} tools"
LABEL "org.opencontainers.image.description"="Ansible ${VERSION} tools"

# Define uid/gid and user/group names
ENV \
    MY_USER=ansible \
    MY_GROUP=ansible \
    MY_UID=1000 \
    MY_GID=1000

# Add user and group
RUN set -eux \
    && addgroup -g ${MY_GID} ${MY_GROUP} \
    && adduser -h /home/ansible -s /bin/bash -G ${MY_GROUP} -D -u ${MY_UID} ${MY_USER} \
    \
    && mkdir /home/ansible/.gnupg \
    && chown ansible:ansible /home/ansible/.gnupg \
    && chmod 0700 /home/ansible/.gnupg \
    \
    && mkdir /home/ansible/.ssh \
    && chown ansible:ansible /home/ansible/.ssh \
    && chmod 0700 /home/ansible/.ssh

# Additional binaries
RUN set -eux \
    && apk add --no-cache \
        bash \
        git \
        gnupg \
        jq \
        openssh-client \
        tar

COPY --from=builder /usr/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/
COPY --from=builder /usr/bin/yq /usr/bin/yq
COPY ./data/docker-entrypoint.sh /docker-entrypoint.sh

WORKDIR /data
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]