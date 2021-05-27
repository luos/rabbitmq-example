#/bin/bash
set -ex

mkdir -p /simulator
cp -rf /apps/simulator/* /simulator/
ls -alh /simulator
pushd /simulator
mix local.hex --force
mix local.rebar --force
mix deps.compile
mix run  lib/simulate.exs  --host $RABBITMQ_HOST  --port 5672 --instance-name $INSTANCE_NAME
