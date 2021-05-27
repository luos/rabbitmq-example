FROM debian:jessie
RUN apt update
RUN apt install -y openssl wget vim
RUN apt install -y collectd socat logrotate
RUN apt-key adv --keyserver "hkps.pool.sks-keyservers.net" --recv-keys "0x6B73A36E6026DFCA"
RUN apt install -y apt-transport-https
RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
RUN dpkg -i erlang-solutions_2.0_all.deb
RUN apt update
RUN apt install -y esl-erlang=1:19.3
#RUN echo "deb https://dl.bintray.com/rabbitmq/debian jessie erlang-21.x" > "/etc/apt/sources.list.d/bintray.erlang.list"
#RUN apt update
#RUN apt install -y erlang-nox=21.0
RUN wget https://github.com/rabbitmq/rabbitmq-server/releases/download/rabbitmq_v3_6_6/rabbitmq-server_3.6.6-1_all.deb
RUN dpkg -i --force-all rabbitmq-server*.deb
RUN mkdir -p /usr/lib/rabbitmq/plugins
CMD [ "bash", "-c", "rabbitmq-server" ]

