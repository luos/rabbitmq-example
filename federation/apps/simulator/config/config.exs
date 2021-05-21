import Config

:ok = Application.ensure_started(:sasl)

config :logger, :console,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  compile_time_purge_level: :info

config :sasl, sasl_error_logger: false
