FROM ubuntu:10.04

RUN apt-get update
RUN apt-get -y install curl mercurial
RUN apt-get -y install make gcc ed bison
RUN apt-get -y install emacs22-nox

RUN adduser gopher

ENV GOROOT /home/gopher/go
ENV GOBIN /home/gopher/go/bin

WORKDIR /home/gopher
RUN curl --remote-name http://bradfitz-public.s3-website-us-east-1.amazonaws.com/go.tar.gz
RUN tar -zxvf go.tar.gz
RUN rm go.tar.gz
RUN mkdir -p $GOBIN

ENV GOVERS aaa902b78832
RUN cd $GOROOT && hg update -C $GOVERS
RUN echo $GOVERS > $GOROOT/VERSION

RUN chown -R gopher.gopher $GOROOT
USER gopher
RUN cd $GOROOT/src && ./make.bash

ENV PATH /home/gopher/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV HOME /home/gopher
ENTRYPOINT /bin/bash

