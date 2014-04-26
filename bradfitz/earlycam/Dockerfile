FROM ubuntu:10.04

RUN apt-get update
RUN apt-get -y install curl mercurial
RUN apt-get -y install make gcc ed bison
RUN apt-get -y install emacs22-nox
RUN apt-get -y install git-core

RUN adduser gopher

ENV GOROOT /home/gopher/go
ENV GOBIN /home/gopher/go/bin

WORKDIR /home/gopher
RUN curl --remote-name http://bradfitz-public.s3-website-us-east-1.amazonaws.com/go.tar.gz
RUN tar -zxvf go.tar.gz
RUN rm go.tar.gz
RUN mkdir -p $GOBIN

ENV GOVERS afd6198fb082
RUN cd $GOROOT && hg update -C $GOVERS
RUN echo $GOVERS > $GOROOT/VERSION

RUN chown -R gopher.gopher $GOROOT
RUN apt-get -y install libc6-dev-i386
RUN apt-get -y install sudo
RUN echo "gopher ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER gopher
ENV GOARCH 386
RUN cd $GOROOT/src && ./make.bash

ENV CAMVERS e7b00b6e2c3955350d1c714637f16e8b985511aa
RUN cd /home/gopher && git clone https://github.com/bradfitz/camlistore.git
RUN cd /home/gopher/camlistore && git reset --hard $CAMVERS

ENV PATH /home/gopher/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV HOME /home/gopher
ENTRYPOINT /bin/bash

