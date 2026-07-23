FROM ubuntu:26.04 AS builder

RUN apt-get update && \
    apt upgrade -y
        

ENTRYPOINT [ "/bin/bash" ]
