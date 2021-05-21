defmodule Utils do
  def header_value(key, headers) do
    case List.keyfind(headers, key, 0) do
      {_, _, value} -> value
      _ -> "unknown " <> key
    end
  end

end
