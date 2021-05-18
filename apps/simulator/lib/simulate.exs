require Logger
require Utils
require Calendar
alias AMQP.{Connection, Channel, Queue, Basic, Exchange, Confirm}

:application.set_env(:amqp_client, :gen_server_call_timeout, 120_000)
:logger.add_primary_filter(
  :ignore_rabbitmq_progress_reports,
  {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
)



{opts, []} =
  OptionParser.parse!(System.argv(),
    strict: [host: :string, port: :integer, instance_name: :string]
  )

opts == [] && raise "Missing options. Required --host string --port integer"

commands_exchange = "commands"
events_exchange = "events"
replies_exchange = "replies"
shovel_incoming_exchange = "shovel-incoming"

username = "guest"
password = "guest"
instance_name = opts[:instance_name]

devices = [
  "unit-1",
  # "unit-2",
  "csm-1"
  # "csm-2"
]

other_devices = devices -- [instance_name]
display_name = instance_name <> "@" <> opts[:host]
queue_name = "Queue for " <> instance_name

do_log = fn log ->
  Logger.info("[" <> instance_name <> "@" <> opts[:host] <> "] " <> log)
end

create_headers = fn ->
  [
    reply_to: "reply_to." <> instance_name,
    sender_display_name: instance_name <> "@" <> opts[:host],
    correlation_id: 3
  ]
end

#  connect function, retries if there was an error
connect = fn connect ->
  case Connection.open(
         host: opts[:host],
         port: opts[:port],
         username: username,
         password: password
       ) do
    {:ok, conn} ->
      {:ok, conn}

    {:error, error} ->
      do_log.("Connection error, retrying: #{error}")
      :timer.sleep(5000)
      connect.(connect)
  end
end

# We open a connection, retry until RabbitMQ comes up
{:ok, conn} = connect.(connect)

# We have to have a channel to communicate to RabbitMQ
{:ok, channel} = Channel.open(conn)
# Turn of publish confirms
:ok = Confirm.select(channel)

# We are running on a single thread anyway, so lets prefetch 5 messages
:ok = Basic.qos(channel, prefetch_count: 5)

do_log.("Opened channel on connection=#{opts[:host]}:#{opts[:port]}")

# Declaring our own, single queue
{:ok, _} = Queue.declare(channel, queue_name, durable: true)

for exchange <- [commands_exchange, shovel_incoming_exchange] do
  Queue.bind(channel, queue_name, exchange, routing_key: "command." <> instance_name)
end

for exchange <- [replies_exchange, shovel_incoming_exchange] do
  Queue.bind(channel, queue_name, exchange, routing_key: "reply_to." <> instance_name)
end

for exchange <- [events_exchange, shovel_incoming_exchange] do
  Queue.bind(channel, queue_name, exchange, routing_key: "event.#")
end

do_log.("Declared queue '#{queue_name}' and bound to exchanges")

# We only consume our own queue
Basic.consume(channel, queue_name)

# When the device comes up we publish an "online" event
Basic.publish(channel, events_exchange, "event." <> instance_name, "online",
  headers: create_headers.()
)

# We log any event received, currently we are subscribed to all events
handle_event = fn _channel, device, message ->
  do_log.("Received event: '" <> message <> "' from '" <> device <> "'")
end

# We print any replies we receive to our RPC calls
handle_reply = fn _channel, device, message ->
  do_log.("Received reply: '" <> message <> "' from '" <> device <> "'")
end

# Handling of an RPC command. We sleep for some random time to simulate work
handle_command = fn channel, reply_to, message ->
  do_log.("Received command: " <> message <> " from " <> reply_to)
  # doing some work
  sleep = :rand.uniform(5000) + 1000
  :timer.sleep(sleep)
  do_log.("Publishing RPC result #{sleep} | #{reply_to} ")

  Basic.publish(channel, "replies", reply_to, "Processed RPC #{sleep} |  " <> message,
    headers: create_headers.()
  )

  Confirm.wait_for_confirms(channel)
end

# Publishing of an event
raise_event = fn channel ->
  now = DateTime.utc_now() |> DateTime.to_iso8601()
  event = "Event " <> now <> " " <> display_name
  do_log.("Raising event: " <> event)

  Basic.publish(channel, events_exchange, "event." <> instance_name, event,
    headers: create_headers.()
  )
end

# Starting an RPC call
start_rpc = fn channel ->
  now = DateTime.utc_now() |> DateTime.to_iso8601()

  target = other_devices |> Enum.random()
  rpc = "RPC " <> now <> " " <> display_name <> " to " <> target
  do_log.("Starting RPC: " <> rpc)

  Basic.publish(channel, "commands", "command." <> target, rpc,
    persistent: true,
    mandatory: true,
    headers: create_headers.()
  )

  Confirm.wait_for_confirms(channel)
end

# The application has a recursive loop function waiting for messages forever
loop = fn loop, channel ->
  receive do
    {:basic_consume_ok, _} ->
      loop.(loop, channel)

    # receiving messages from RabbitMQ
    {:basic_deliver, payload, meta} ->
      # IO.inspect(meta)

      # depending on how the routing key starts we decide what kind of message we received
      case meta[:routing_key] do
        # event message received
        "event." <> _device ->
          handle_event.(
            channel,
            Utils.header_value("sender_display_name", meta[:headers]),
            payload
          )

          Basic.ack(channel, meta[:delivery_tag])

        # an RPC call was received
        "command." <> ^instance_name ->
          reply_to = Utils.header_value("reply_to", meta[:headers])
          handle_command.(channel, reply_to, payload)
          Basic.ack(channel, meta[:delivery_tag])

        # this is a reply to one of our RPC calls
        "reply_to." <> ^instance_name ->
          handle_reply.(
            channel,
            Utils.header_value("sender_display_name", meta[:headers]),
            payload
          )

          Basic.ack(channel, meta[:delivery_tag])
      end

      # we loop back on ourselves to wait for more messages
      loop.(loop, channel)

    # unknown message
    msg ->
      IO.inspect(msg)
      loop.(loop, channel)
  after
    :rand.uniform(20) * 1000 + 10000 ->
      # after some random timeout if we have not received any messages we
      # either start an RPC call or raise an event
      case :rand.uniform(2) do
        1 ->
          raise_event.(channel)

        2 ->
          start_rpc.(channel)
      end

      loop.(loop, channel)
  end
end

# start the message receive loop
loop.(loop, channel)

do_log.("Shutting down")

:ok = Channel.close(channel)
:ok = Connection.close(conn)
