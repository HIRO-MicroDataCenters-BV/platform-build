FROM ubuntu:26.04 AS builder

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt upgrade -y

WORKDIR /platform-build

COPY . .

RUN ./ipxe/bin/build.sh install_dependencies
RUN ./matchbox/bin/build.sh install_dependencies $TARGETARCH
RUN ./frr/bin/build.sh install_dependencies

ENTRYPOINT [ "/bin/bash" ]
