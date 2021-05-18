#/bin/bash
set -ex
if test -f "/apps/lock"; then
    sleep 15
fi
touch /apps/lock
pushd /apps/simulator
mix local.hex --force 
mix local.rebar --force 
mix deps.compile
rm /apps/lock || true
mix run  lib/simulate.exs  --host $RABBITMQ_HOST  --port 5672 --instance-name $INSTANCE_NAME
