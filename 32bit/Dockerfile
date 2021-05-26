FROM i386/debian:stretch
RUN apt update && apt -y install git autoconf make gcc ncurses-dev libssl-dev
RUN git clone https://github.com/erlang/otp.git && cd otp && git checkout OTP-23.3.4
RUN export FLAGS=""; export MAKEFLAGS='-j6';  cd otp && ./otp_build autoconf && \
    ./configure  $FLAGS --with-ssl=/usr/include/openssl/ --disable-hipe \
    && make && make install 

RUN apt install -y wget logrotate socat procps vim
RUN wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.8.16/rabbitmq-server_3.8.16-1_all.deb
RUN dpkg --force-all -i rabbitmq-server_3.8.16-1_all.deb
ENTRYPOINT [ "bash", "-c" ]
CMD ["rabbitmq-server"]
