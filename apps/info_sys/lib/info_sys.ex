defmodule InfoSys do
  @backends [InfoSys.Wolfram]
  alias InfoSys.Cache

  @moduledoc """
  Documentation for `InfoSys`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> InfoSys.hello()
      :world

  """
  def hello do
    :world
  end

  defmodule Result do
    defstruct score: 0, text: nil, backend: nil
  end

  def compute(query, opts \\ []) do
    opts = Keyword.put_new(opts, :limit, 10)
    backends = opts[:backends] || @backends
    timeout = opts[:timeout] || 10_000

    {uncached_backends, cached_results} = fetch_cached_results(backends, query, opts)

    uncached_backends
    |> Enum.map(&async_query(&1, query, opts))
    # Task.yield waits for the tasks to be completed in a interval
    |> Task.yield_many(timeout)
    # Map through each result
    |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)
    |> Enum.flat_map(fn
      {:ok, results} -> results
      _ -> []
    end)
    |> write_results_to_cache(query, opts)
    |> Kernel.++(cached_results)
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(opts[:limit])
  end

  defp fetch_cached_results(backends, query, opts) do
    # backends = list of modules (tasks)

    {uncached_backends, results} =
      Enum.reduce(backends, {[], []}, fn backend, {uncached_backends, acc_results} ->
        case Cache.fetch({backend.name(), query, opts[:limit]}) do
          {:ok, results} -> {uncached_backends, [results | acc_results]}
          :error -> {[backend | uncached_backends], acc_results}
        end
      end)

    {uncached_backends, List.flatten(results)}
  end

  defp write_results_to_cache(results, query, opts) do
    Enum.map(results, fn %Result{backend: backend} = result ->
      :ok = Cache.put({backend.name(), query, opts[:limit]}, result)
      result
    end)
  end

  defp async_query(backend, query, opts) do
    # Task.Supervisor defines a supervisor to supervise tasks
    Task.Supervisor.async_nolink(InfoSys.TaskSupervisor, backend, :compute, [query, opts],
      shutdown: :brutal_kill
    )
  end
end
