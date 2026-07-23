FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    apt upgrade -y


ENTRYPOINT [ "/bin/bash" ]
