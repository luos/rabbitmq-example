#/bin/bash
set -ex
LOCK=/apps/lock

# hack so the two compiles dont disturb each other
sleep .$[ ( $RANDOM % 1000 ) + 1 ]s
while test -f "$LOCK"; do
    sleep 5
done

touch $LOCK
pushd /apps/simulator
mix local.hex --force
mix local.rebar --force
mix deps.compile
rm $LOCK || true
sleep 5
mix run  lib/simulate.exs  --host $RABBITMQ_HOST  --port 5672 --instance-name $INSTANCE_NAME
