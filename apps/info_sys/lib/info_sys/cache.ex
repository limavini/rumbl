defmodule InfoSys.Cache do
  # ets is the erlang term storage. in-memory storage (like redis)
  use GenServer
  @clear_interval :timer.seconds(60)

  # Client function for "external" access
  def put(name \\ __MODULE__, key, value) do
    # Insert a tuple on the table. The table name is the same as the the GenServer's name.
    true = :ets.insert(tab_name(name), {key, value})
    :ok
  end

  # Client function for "external" acess
  def fetch(name \\ __MODULE__, key) do
    {:ok, :ets.lookup_element(tab_name(name), key, 2)}
  rescue
    # Error handling since ets trows an ArgumentError if the key doesn't exist
    ArgumentError -> :error
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    state = %{
      interval: opts[:clear_interval] || @clear_interval,
      timer: nil,
      table: new_table(opts[:name])
    }

    {:ok, schedule_clear(state)}
  end

  def handle_info(:clear, state) do
    :ets.delete_all_objects(state.table)
    {:noreply, schedule_clear(state)}
  end

  defp schedule_clear(state) do
    %{state | timer: Process.send_after(self(), :clear, state.interval)}
  end

  defp new_table(name) do
    name
    |> tab_name()
    |> :ets.new([
      # a kind of table that acts as key-value storage
      :set,
      # allow us to locate a table by its name
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp tab_name(name), do: :"#{name}_cache"
end
