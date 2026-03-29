ARG BASE_VERSION=24.04

ARG BASE_IMAGE=ubuntu:$BASE_VERSION

FROM ${BASE_IMAGE} AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

ARG BASE_VERSION
ARG PG_VERSION=16
ARG PACKAGE_SUFFIX=t64

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive PG_VERSION=${PG_VERSION} BASE_VERSION=${BASE_VERSION}

ARG ONLYOFFICE_VALUE=onlyoffice

# Add USTC apt source
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/ubuntu.sources
RUN apt-get -y update && \
    apt-get -yq install wget apt-transport-https gnupg locales lsb-release
RUN sed -i 's/http:/https:/g' /etc/apt/sources.list.d/ubuntu.sources

RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# locale and MS fonts
RUN locale-gen en_US.UTF-8 && \
    locale-gen zh_CN.UTF-8
RUN apt-get -y update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    ACCEPT_EULA=Y apt-get -yq install \
    ttf-mscorefonts-installer
RUN if [  $(ls -l /usr/share/fonts/truetype/msttcorefonts | wc -l) -ne 61 ]; \
        then echo 'msttcorefonts failed to download'; exit 1; fi

RUN apt-get -y update && \
    apt-get -yq install \
        adduser \
        apt-utils \
        bomstrip \
        cron \
        curl \
        libaio1${PACKAGE_SUFFIX} \
        libasound2${PACKAGE_SUFFIX} \
        libboost-regex-dev \
        libcairo2 \
        libcurl3-gnutls \
        libcurl4 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libstdc++6 \
        libxml2 \
        libxss1 \
        libxtst6 \
        nano \
        net-tools \
        netcat-openbsd \
        nginx-extras \
        pwgen \
        supervisor \
        unixodbc-dev \
        xvfb \
        xxd \
        zlib1g || dpkg --configure -a
    # Added dpkg --configure -a to handle installation issues with rabbitmq-server on arm64 architecture

RUN sed 's|\(application\/zip.*\)|\1\n    application\/wasm wasm;|' -i /etc/nginx/mime.types && \
    find /usr/lib /lib -name "libaio.so.1$PACKAGE_SUFFIX" -exec bash -c 'ln -sf "$0" "$(dirname "$0")/libaio.so.1"' {} \; && \
    service supervisor stop && \
    service nginx stop && \
    rm -rf /var/lib/apt/lists/*

COPY config/supervisor/supervisor /etc/init.d/
COPY config/supervisor/ds/*.conf /etc/supervisor/conf.d/
COPY run-document-server.sh /app/ds/run-document-server.sh
COPY onlyoffice-documentserver_9.0.2-1_amd64.deb /tmp/ds.deb

EXPOSE 80 443

ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_NAME=documentserver
ARG PRODUCT_EDITION=
ARG PACKAGE_VERSION=

ENV COMPANY_NAME=$COMPANY_NAME \
    PRODUCT_NAME=$PRODUCT_NAME \
    PRODUCT_EDITION=$PRODUCT_EDITION \
    DS_PLUGIN_INSTALLATION=false \
    DS_DOCKER_INSTALLATION=true

RUN apt-get -y update && \
    apt-get -yq install /tmp/ds.deb && \
    chmod 755 /etc/init.d/supervisor && \
    sed "s/COMPANY_NAME/${COMPANY_NAME}/g" -i /etc/supervisor/conf.d/*.conf && \
    service supervisor stop && \
    chmod 755 /app/ds/*.sh && \
    rm -f /tmp/ds.deb && \
    rm -rf /var/log/$COMPANY_NAME

RUN apt-get -y update && \
    apt-get -yq install \
        postgresql-client && \
    rm -rf /var/lib/apt/lists/*


VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /usr/share/fonts/truetype/custom

ENTRYPOINT ["/app/ds/run-document-server.sh"]
