if Code.ensure_loaded?(:hackney) do
  defmodule Tesla.Adapter.Hackney do
    @moduledoc """
    Adapter for [hackney](https://github.com/benoitc/hackney)

    Remember to add `{:hackney, "~> 1.6"}` to dependencies (and `:hackney` to applications in `mix.exs`)
    Also, you need to recompile tesla after adding `:hackney` dependency:

    ```
    mix deps.clean tesla
    mix deps.compile tesla
    ```

    ### Example usage
    ```
    # set globally in config/config.exs
    config :tesla, :adapter, :hackney

    # set per module
    defmodule MyClient do
      use Tesla

      adapter :hackney
    end
    ```
    """
    @behaviour Tesla.Adapter
    alias Tesla.Multipart

    def call(env, opts) do
      with {:ok, status, headers, body} <- request(env, opts || []) do
        %{env | status: status, headers: format_headers(headers), body: format_body(body)}
      else
        {:error, reason} ->
          raise %Tesla.Error{message: "adapter error: #{inspect(reason)}", reason: reason}
      end
    end

    defp format_headers(headers) do
      for {key, value} <- headers do
        {String.downcase(to_string(key)), to_string(value)}
      end
    end

    defp format_body(data) when is_list(data), do: IO.iodata_to_binary(data)
    defp format_body(data) when is_binary(data), do: data

    defp request(env, opts) do
      request(
        env.method,
        Tesla.build_url(env.url, env.query),
        env.headers,
        env.body,
        opts ++ env.opts
      )
    end

    defp request(method, url, headers, %Stream{} = body, opts),
      do: request_stream(method, url, headers, body, opts)

    defp request(method, url, headers, body, opts) when is_function(body),
      do: request_stream(method, url, headers, body, opts)

    defp request(method, url, headers, %Multipart{} = mp, opts) do
      headers = headers ++ Multipart.headers(mp)
      body = Multipart.body(mp)

      request(method, url, headers, body, opts)
    end

    defp request(method, url, headers, body, opts) do
      handle(:hackney.request(method, url, headers, body || '', opts))
    end

    defp request_stream(method, url, headers, body, opts) do
      with {:ok, ref} <- :hackney.request(method, url, headers, :stream, opts) do
        for data <- body, do: :ok = :hackney.send_body(ref, data)
        handle(:hackney.start_response(ref))
      else
        e -> handle(e)
      end
    end

    defp handle({:error, _} = error), do: error
    defp handle({:ok, status, headers}), do: {:ok, status, headers, []}

    defp handle({:ok, status, headers, ref}) when is_reference(ref) do
      with {:ok, body} <- :hackney.body(ref) do
        {:ok, status, headers, body}
      end
    end

    defp handle({:ok, status, headers, body}), do: {:ok, status, headers, body}
  end
end
