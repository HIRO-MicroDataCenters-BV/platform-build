FROM ubuntu:24.04 AS builder

ARG TARGETARCH

RUN apt-get update && \
    apt upgrade -y

WORKDIR /platform-build

COPY . .

RUN ./ipxe/bin/build.sh install_dependencies
RUN ./matchbox/bin/build.sh install_dependencies $TARGETARCH
RUN ./frr/bin/build.sh install_dependencies

ENTRYPOINT [ "/bin/bash" ]
