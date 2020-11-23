FROM ubuntu:16.04
LABEL maintainer="sergey.nevmerzhitsky@gmail.com"

WORKDIR /tmp/

RUN set -ex; \
    dpkg --add-architecture i386; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        binutils \
        cabextract \
        curl \
        # To take screenshots of Xvfb display
        imagemagick \
        p7zip \
        software-properties-common \
        wget \
        unzip \
        xz-utils \
        xvfb \
        x11vnc

RUN set -ex; \
    wget -nc https://dl.winehq.org/wine-builds/winehq.key; \
    apt-key add winehq.key; \
    apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends \
        winehq-stable=5.0.3~xenial; \
    rm winehq.key

RUN set -ex; \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
    chmod +x winetricks; \
    mv winetricks /usr/local/bin

COPY waitonprocess.sh /docker/
RUN chmod a+rx /docker/waitonprocess.sh

ARG USER=winer
ARG HOME=/home/$USER
ARG USER_ID=1000
# To access the values from children containers.
ENV USER=$USER \
    HOME=$HOME

RUN set -ex; \
    groupadd $USER;\
    useradd -u $USER_ID -d $HOME -g $USER -ms /bin/bash $USER

USER $USER

ENV WINEARCH=win32 \
    WINEPREFIX=$HOME/.wine \
    DISPLAY=:1 \
    SCREEN_NUM=0 \
    SCREEN_WHD=1366x768x24
ENV MT4DIR=$WINEPREFIX/drive_c/mt4

# @TODO Install actual versions of Mono and Gecko dynamically
ADD cache $HOME/.cache
USER root
RUN chown $USER:$USER -R $HOME/.cache

USER $USER
RUN set -ex; \
    wine wineboot --init; \
    /docker/waitonprocess.sh wineserver; \
    winetricks --unattended dotnet40; \
    /docker/waitonprocess.sh wineserver

RUN set -ex; \
    wget https://dl.winehq.org/wine/wine-mono/4.7.1/wine-mono-4.7.1.msi && \
    mv wine-mono-4.7.1.msi $HOME/.cache/wine

RUN set -ex; \
    wget http://dl.winehq.org/wine/wine-gecko/2.47.1/wine-gecko-2.47.1-x86.msi && \
    mv wine-gecko-2.47.1-x86.msi $HOME/.cache/wine

RUN set -ex; \
    wget http://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86.msi && \
    mv wine_gecko-2.47-x86.msi $HOME/.cache/wine

USER root
COPY run_mt.sh screenshot.sh /docker/
RUN set -e; \
    chmod a+rx /docker/run_mt.sh /docker/screenshot.sh; \
    mkdir -p /tmp/screenshots/; \
    chown winer:winer /tmp/screenshots/

USER $USER
WORKDIR $MT4DIR
VOLUME /tmp/screenshots/

ENTRYPOINT ["/bin/bash"]
CMD ["/docker/run_mt.sh"]

# @TODO Add ability to list logs which content should be redirected to STDOUT with a prefix
# @TODO Add ability to change TZ of the OS
