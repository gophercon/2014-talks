FROM ubuntu:12.04

RUN apt-get update
RUN apt-get -y install curl mercurial
RUN apt-get -y install make gcc bison
RUN apt-get -y install emacs23-nox
RUN apt-get -y install git-core

RUN adduser gopher

ENV GOROOT /home/gopher/go
ENV GOBIN /home/gopher/go/bin

WORKDIR /home/gopher
RUN curl --remote-name http://bradfitz-public.s3-website-us-east-1.amazonaws.com/go.tar.gz
RUN tar -zxvf go.tar.gz
RUN rm go.tar.gz
RUN mkdir -p $GOBIN

ENV GOVERS f613443bb13a
RUN cd $GOROOT && hg pull https://code.google.com/p/go
RUN cd $GOROOT && hg update -C $GOVERS
RUN echo $GOVERS > $GOROOT/VERSION

RUN chown -R gopher.gopher $GOROOT
RUN apt-get -y install sudo
RUN echo "gopher ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER gopher
ENV PATH /home/gopher/bin:/home/gopher/src/camlistore.org/bin:/home/gopher/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV HOME /home/gopher

RUN cd $GOROOT/src && ./make.bash

ENV CAMVERS 8ac8437e91cbce921cb7245d44f5191c1916b170
ENV GOPATH /home/gopher
RUN mkdir /home/gopher/src /home/gopher/bin
RUN cd /home/gopher/src && git clone https://github.com/bradfitz/camlistore.git camlistore.org
RUN cd /home/gopher/src/camlistore.org && git reset --hard $CAMVERS
RUN cd /home/gopher/src/camlistore.org && make

ENV USER gopher
RUN camput init --newkey

RUN sudo apt-get -y install fuse

RUN (echo "#!/bin/sh"; echo "exec camlistored 2>/dev/null") > /home/gopher/bin/d
RUN chmod +x /home/gopher/bin/d
RUN sudo usermod -a -G fuse gopher

RUN go get code.google.com/p/go.tools/cmd/godoc

ENTRYPOINT /bin/bash

