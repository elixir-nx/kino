defmodule Kino.Frame do
  @moduledoc """
  A placeholder for outputs.

  A frame wraps outputs that can be dynamically updated at
  any time.

  Also see `Kino.animate/3` which offers a convenience on
  top of this kino.

  ## Examples

      frame = Kino.Frame.new() |> Kino.render()

      for i <- 1..100 do
        Kino.Frame.render(frame, i)
        Process.sleep(50)
      end

  Or with a scheduled task in the background.

      frame = Kino.Frame.new() |> Kino.render()

      Kino.Frame.periodically(frame, 50, 0, fn i ->
        Kino.Frame.render(frame, i)
        {:cont, i + 1}
      end)
  """

  @doc false
  use GenServer, restart: :temporary

  defstruct [:ref, :pid]

  @opaque t :: %__MODULE__{ref: String.t(), pid: pid()}

  @typedoc false
  @type state :: %{outputs: list(Kino.Output.t())}

  @doc """
  Creates a new frame.
  """
  @spec new() :: t()
  def new() do
    ref = System.unique_integer() |> Integer.to_string()
    {:ok, pid} = Kino.start_child({__MODULE__, ref})
    %__MODULE__{ref: ref, pid: pid}
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Renders the given term within the frame.

  This works similarly to `Kino.render/1`, but the rendered
  output replaces existing frame contents.

  ## Options

    * `:to` - the client id to whom the update is directed. This
      option is useful when updating frame in response to client
      events, such as form submission

    * `:history` - if the update will be part of the frame history.
      Defaults to `true`, unless `:to` is given. Direct updates are
      never a part of the history

  """
  @spec render(t(), term(), keyword()) :: :ok
  def render(frame, term, opts \\ []) do
    opts = Keyword.validate!(opts, [:to, :history])
    destination = update_destination_from_opts!(opts)
    GenServer.cast(frame.pid, {:render, term, destination})
  end

  defp update_destination_from_opts!(opts) do
    if to = opts[:to] do
      if opts[:history] do
        raise ArgumentError,
              "direct updates sent via :to are never part of the frame history," <>
                " passing :history is not supported"
      end

      {:client, to}
    else
      if Keyword.get(opts, :history, true) do
        :default
      else
        :clients
      end
    end
  end

  @doc """
  Renders and appends the given term to the frame.

  ## Options

    * `:to` - the client id to whom the update is directed. This
      option is useful when updating frame in response to client
      events, such as form submission

    * `:history` - if the update will be part of the frame history.
      Defaults to `true`, unless `:to` is given. Direct updates are
      never a part of the history

  """
  @spec append(t(), term(), keyword()) :: :ok
  def append(frame, term, opts \\ []) do
    opts = Keyword.validate!(opts, [:to, :history])
    destination = update_destination_from_opts!(opts)
    GenServer.cast(frame.pid, {:append, term, destination})
  end

  @doc """
  Removes all outputs within the given frame.

  ## Options

    * `:to` - the client id to whom the update is directed. This
      option is useful when updating frame in response to client
      events, such as form submission

    * `:history` - if the update will be part of the frame history.
      Defaults to `true`, unless `:to` is given. Direct updates are
      never a part of the history

  """
  @spec clear(t(), keyword()) :: :ok
  def clear(frame, opts \\ []) do
    opts = Keyword.validate!(opts, [:to, :history])
    destination = update_destination_from_opts!(opts)
    GenServer.cast(frame.pid, {:clear, destination})
  end

  @doc """
  Registers a callback to run periodically in the frame process.

  The callback is run every `interval_ms` milliseconds and receives
  the accumulated value. The callback should return either of:

    * `{:cont, acc}` - the continue with the new accumulated value

    * `:halt` - to no longer schedule callback evaluation

  The callback is run for the first time immediately upon registration.
  """
  @spec periodically(t(), pos_integer(), term(), (term() -> {:cont, term()} | :halt)) :: :ok
  def periodically(frame, interval_ms, acc, fun) do
    GenServer.cast(frame.pid, {:periodically, interval_ms, acc, fun})
  end

  @doc false
  @spec get_outputs(t()) :: list(Kino.Output.t())
  def get_outputs(frame) do
    GenServer.call(frame.pid, :get_outputs)
  end

  @impl true
  def init(ref) do
    {:ok, %{ref: ref, outputs: []}}
  end

  @impl true
  def handle_cast({:render, term, destination}, state) do
    output = Kino.Render.to_livebook(term)
    put_update(destination, state.ref, [output], :replace)
    state = %{state | outputs: [output]}
    {:noreply, state}
  end

  def handle_cast({:append, term, destination}, state) do
    output = Kino.Render.to_livebook(term)
    put_update(destination, state.ref, [output], :append)
    state = %{state | outputs: [output | state.outputs]}
    {:noreply, state}
  end

  def handle_cast({:clear, destination}, state) do
    put_update(destination, state.ref, [], :replace)
    state = %{state | outputs: []}
    {:noreply, state}
  end

  def handle_cast({:periodically, interval_ms, acc, fun}, state) do
    periodically_iter(interval_ms, acc, fun)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_outputs, _from, state) do
    {:reply, state.outputs, state}
  end

  @impl true
  def handle_info({:periodically_iter, interval_ms, acc, fun}, state) do
    periodically_iter(interval_ms, acc, fun)
    {:noreply, state}
  end

  defp periodically_iter(interval_ms, acc, fun) do
    case fun.(acc) do
      {:cont, acc} ->
        Process.send_after(self(), {:periodically_iter, interval_ms, acc, fun}, interval_ms)

      :halt ->
        :ok
    end
  end

  defp put_update(destination, ref, outputs, type) do
    output = Kino.Output.frame(outputs, %{ref: ref, type: type})

    case destination do
      :default -> Kino.Bridge.put_output(output)
      {:client, to} -> Kino.Bridge.put_output_to(to, output)
      :clients -> Kino.Bridge.put_output_to_clients(output)
    end
  end
end
