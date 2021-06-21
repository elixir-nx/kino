defmodule Kino.ETS do
  @moduledoc """
  A widget for interactively viewing an ETS table.

  ## Examples

      tid = :ets.new(:users, [:set, :public])
      Kino.ETS.start(tid)

      Kino.ETS.start(:elixir_config)
  """

  use GenServer, restart: :temporary

  defstruct [:pid]

  @type t :: %__MODULE__{pid: pid()}

  @typedoc false
  @type state :: %{
          parent_monitor_ref: reference(),
          tid: :ets.tid()
        }

  @doc """
  Starts a widget process representing the given ETS table.

  Note that private tables cannot be read by an arbitrary process,
  so the given table must have either public or protected access.
  """
  @spec start(:ets.tid()) :: t()
  def start(tid) do
    case :ets.info(tid, :protection) do
      :private ->
        raise ArgumentError,
              "the given table must be either public or protected, but a private one was given"

      :undefined ->
        raise ArgumentError,
              "the given table identifier #{inspect(tid)} does not refer to an existing ETS table"

      _ ->
        :ok
    end

    parent = self()
    opts = [tid: tid, parent: parent]

    {:ok, pid} = DynamicSupervisor.start_child(Kino.WidgetSupervisor, {__MODULE__, opts})

    %__MODULE__{pid: pid}
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    tid = Keyword.fetch!(opts, :tid)
    parent = Keyword.fetch!(opts, :parent)

    parent_monitor_ref = Process.monitor(parent)

    {:ok, %{parent_monitor_ref: parent_monitor_ref, tid: tid}}
  end

  @impl true
  def handle_info({:connect, pid}, state) do
    table_name = :ets.info(state.tid, :name)
    name = "ETS #{inspect(table_name)}"

    columns =
      case :ets.match_object(state.tid, :_, 1) do
        {[record], _} -> columns_structure_for_records([record])
        :"$end_of_table" -> []
      end

    send(
      pid,
      {:connect_reply, %{name: name, columns: columns, features: [:refetch, :pagination]}}
    )

    {:noreply, state}
  end

  def handle_info({:get_rows, pid, rows_spec}, state) do
    records = get_records(state.tid, rows_spec)
    rows = Enum.map(records, &record_to_row/1)
    total_rows = :ets.info(state.tid, :size)

    columns =
      case records do
        [] -> :initial
        records -> columns_structure_for_records(records)
      end

    send(pid, {:rows, %{rows: rows, total_rows: total_rows, columns: columns}})

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _object, _reason}, %{parent_monitor_ref: ref} = state) do
    {:stop, :shutdown, state}
  end

  defp columns_structure_for_records(records) do
    max_columns =
      records
      |> Enum.map(&tuple_size/1)
      |> Enum.max()

    for idx <- 0..(max_columns - 1) do
      %{key: idx, label: to_string(idx)}
    end
  end

  defp get_records(tid, rows_spec) do
    query = :ets.table(tid)
    cursor = :qlc.cursor(query)

    if rows_spec.offset > 0 do
      :qlc.next_answers(cursor, rows_spec.offset)
    end

    records = :qlc.next_answers(cursor, rows_spec.limit)
    :qlc.delete_cursor(cursor)
    records
  end

  defp record_to_row(record) do
    fields =
      record
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Map.new(fn {val, idx} -> {idx, inspect(val)} end)

    # Note: id is opaque to the client, and we don't need it for now
    %{id: nil, fields: fields}
  end
end
