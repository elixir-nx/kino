defmodule Kino.Wizard do
  @moduledoc ~S"""
      import Kino.Control
      import Kino.Shorts
      import Kino.Wizard

      defmodule MyWizard do
        # @behaviour Kino.Wizard

        def init(_data, :ok) do
          {:ok, %{page: 1, name: nil, address: nil}}
        end

        defp step_one(%{data: %{name: name}}, state) do
          if name == "" do
            %{state | name: name}
          else
            %{state | name: name, page: 2}
          end
        end

        defp step_two(%{data: %{address: address}}, state) do
          case address do
            "BUMP" <> _ -> %{state | address: address <> "!"}
            "" -> %{state | address: ""}
            _ -> %{state | address: address, page: 3}
          end
        end

        defp go_back(_, state) do
          %{state | page: state.page - 1}
        end

        def render(%{page: 1} = state) do
          form(
            [name: Kino.Input.text("Name", default: state.name)],
            submit: "Step one"
          )
          |> control(&step_one/2)
        end

        def render(%{page: 2} = state) do
          Kino.Control.form(
            [address: Kino.Input.text("Address", default: state.address)],
            submit: "Step two"
          )
          |> control(&step_two/2)
          |> add_go_back()
        end

        def render(%{page: 3} = state) do
          "Well done, #{state.name}. You live in #{state.address}."
          |> add_go_back()
        end

        defp add_go_back(element) do
          button =
            button("Go back")
            |> control(&go_back/2)

          grid([element, button])
        end
      end

      Kino.Wizard.new(MyWizard, :ok, "Get started")
  """

  defmodule Server do
    @moduledoc false

    use GenServer

    def start_link({mod_frame_state, data}) do
      GenServer.start_link(__MODULE__, {mod_frame_state, data})
    end

    def control(from, fun) when is_function(fun, 2) do
      Kino.Control.subscribe(from, {__MODULE__, fun})
      from
    end

    @impl true
    def init({{module, frame, state}, %{origin: client_id} = data}) do
      {:ok, state} = module.init(data, state)
      {:ok, render(module, frame, client_id, state)}
    end

    @impl true
    def handle_info({{__MODULE__, fun}, data}, {module, frame, client_id, state}) do
      state = fun.(data, state)
      {:noreply, render(module, frame, client_id, state)}
    end

    defp render(module, frame, client_id, state) do
      Kino.Frame.render(frame, module.render(state), to: client_id)
      {module, frame, client_id, state}
    end
  end

  defmodule Watcher do
    @moduledoc false

    use GenServer

    def start_link({mod_frame_state, button}) do
      GenServer.start_link(__MODULE__, {mod_frame_state, button, self()})
    end

    @impl true
    def init({mod_frame_state, button, parent}) do
      {:ok, _} = Kino.Bridge.monitor_clients(self())
      Kino.Control.subscribe(button, :trigger)
      {:ok, {mod_frame_state, parent, %{}}, {:continue, :init}}
    end

    @impl true
    def handle_continue(:init, {mod_frame_state, parent, children}) do
      [_, {_id, sup, _, _}] = Supervisor.which_children(parent)
      {:noreply, {mod_frame_state, sup, children}}
    end

    @impl true
    def handle_info({:trigger, %{origin: origin} = data}, {mod_frame_state, sup, children}) do
      children =
        case DynamicSupervisor.start_child(sup, {Server, {mod_frame_state, data}}) do
          {:ok, pid} -> Map.put(children, origin, pid)
          {:error, _} -> children
        end

      {:noreply, {mod_frame_state, sup, children}}
    end

    def handle_info({:client_leave, client_id}, {mod_frame_state, sup, children}) do
      {pid, children} = Map.pop(children, client_id)
      pid && DynamicSupervisor.terminate_child(sup, pid)
      {:noreply, {mod_frame_state, sup, children}}
    end

    def handle_info(_, state) do
      {:noreply, state}
    end
  end

  defmodule Supervisor do
    @moduledoc false

    use Elixir.Supervisor

    def start_link({mod_frame_state, button}) do
      Elixir.Supervisor.start_link(__MODULE__, {mod_frame_state, button})
    end

    @impl true
    def init({mod_frame_state, button}) do
      children = [
        # If they boot, we always restart them in case of errors
        {DynamicSupervisor, max_restarts: 1_000_000, max_seconds: 1},
        {Watcher, {mod_frame_state, button}}
      ]

      Elixir.Supervisor.init(children, strategy: :one_for_all)
    end
  end

  defdelegate control(from, fun), to: Server

  def new(module, state, text) when is_atom(module) and is_binary(text) do
    new(module, state, fn frame ->
      text
      |> Kino.Control.button()
      |> tap(&Kino.Frame.render(frame, &1))
    end)
  end

  def new(module, state, function) when is_atom(module) and is_function(function, 1) do
    frame = Kino.Frame.new()
    {:ok, _pid} = Kino.start_child({Supervisor, {{module, frame, state}, function.(frame)}})
    frame
  end
end
