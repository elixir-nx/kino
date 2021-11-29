defmodule Kino.Control do
  @moduledoc """
  Various widgets for user interactions.

  Each widget is a UI control element that the user interacts
  with, consequenty producing an event stream.

  Those widgets are often useful paired with `Kino.Frame` for
  presenting content that changes upon user interactions.

  ## Examples

  First, create a control and make sure it is rendered,
  either by placing it at the end of a code cell or by
  explicitly rendering it with `Kino.render/1`.

      button = Kino.Control.button("Hello")

  Next, to receive events from the control, a process needs to
  subscribe to it and specify pick a name to distinguish the
  events.

      Kino.Control.subscribe(button, :hello)

  As the user interacts with the button, the subscribed process
  receives corresponding events.

      IEx.Helpers.flush()
      #=> {:event, :hello, %{origin: #PID<10895.9854.0>}}
      #=> {:event, :hello, %{origin: #PID<10895.9854.0>}}
  """

  defstruct [:attrs]

  @type t :: %__MODULE__{attrs: Kino.Output.control_attrs()}

  defp new(attrs) do
    token = Kino.Bridge.generate_token()
    id = {token, attrs} |> :erlang.phash2() |> Integer.to_string()

    attrs =
      Map.merge(attrs, %{
        id: id,
        destination: Kino.SubscriptionManager.cross_node_name()
      })

    %__MODULE__{attrs: attrs}
  end

  @doc """
  Creates a new button.
  """
  @spec button(String.t()) :: t()
  def button(label) when is_binary(label) do
    new(%{type: :button, label: label})
  end

  @doc """
  Creates a new keyboard control.

  This widget is represented as button that toggles interception
  mode, in which the given keyboard events are captured.

  ## Event info

  In addition to standard properties, all events inlcude:

    * `:type` - either `:keyup` or `:keydown`

    * `:key` - the value matching the browser [KeyboardEvent.key](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key)

  ## Examples

  Create the widget:

      keyboard = Kino.Control.keyboard([:keyup, :keydown])

  Subscribe to events:

      Kino.Control.subscribe(keyboard, :keyboard)

  As the user types events are streamed:

      IEx.Helpers.flush()
      #=> {:event, :keyboard, %{key: "o", origin: #PID<10895.9854.0>, type: :keydown}}
      #=> {:event, :keyboard, %{key: "k", origin: #PID<10895.9854.0>, type: :keydown}}
      #=> {:event, :keyboard, %{key: "o", origin: #PID<10895.9854.0>, type: :keyup}}
      #=> {:event, :keyboard, %{key: "k", origin: #PID<10895.9854.0>, type: :keyup}}
  """
  @spec keyboard(list(:keyup | :keydown)) :: t()
  def keyboard(events) when is_list(events) do
    if events == [] do
      raise ArgumentError, "expected at least one event, got: []"
    end

    for event <- events do
      unless event in [:keyup, :keydown] do
        raise ArgumentError,
              "expected event to be either :keyup or :keydown, got: #{inspect(event)}"
      end
    end

    new(%{type: :keyboard, events: events})
  end

  @doc """
  Subscribes the calling process to control events.

  The events are sent as `{:event, receive_as, info}`, where
  info is a map with event details. In particular, it always
  includes `:origin`, which is an opaque identifier of the
  client that triggered the event.
  """
  @spec subscribe(t(), term()) :: :ok
  def subscribe(control, receive_as) do
    Kino.SubscriptionManager.subscribe(control.attrs.id, self(), receive_as)
  end

  @doc """
  Unsubscribes the calling process from control events.
  """
  @spec unsubscribe(t()) :: :ok
  def unsubscribe(control) do
    Kino.SubscriptionManager.unsubscribe(control.attrs.id, self())
  end
end