defmodule Kino.ControlTest do
  use ExUnit.Case, async: true

  describe "keyboard/1" do
    test "raises an error for empty option list" do
      assert_raise ArgumentError, "expected at least one event, got: []", fn ->
        Kino.Control.keyboard([])
      end
    end

    test "raises an error when an invalid event is given" do
      assert_raise ArgumentError,
                   "expected event to be either :keyup, :keydown or :status, got: :keyword",
                   fn ->
                     Kino.Control.keyboard([:keyword])
                   end
    end
  end

  describe "form/1" do
    test "raises an error for empty field list" do
      assert_raise ArgumentError, "expected at least one field, got: []", fn ->
        Kino.Control.form([], submit: "Send")
      end
    end

    test "raises an error when value other than input is given" do
      assert_raise ArgumentError,
                   "expected each field to be a Kino.Input widget, got: %{id: 1} for :name",
                   fn ->
                     Kino.Control.form(name: %{id: 1}, submit: "Send")
                   end
    end

    test "raises an error when neither submit nor change trigger is enabled" do
      assert_raise ArgumentError,
                   "expected either :submit or :report_changes option to be enabled",
                   fn ->
                     Kino.Control.form(name: Kino.Input.text("Name"))
                   end
    end

    test "supports boolean values for :reset_on_submit" do
      assert %Kino.Control{attrs: %{reset_on_submit: [:name]}} =
               Kino.Control.form([name: Kino.Input.text("Name")],
                 submit: "Send",
                 reset_on_submit: true
               )
    end

    test "supports boolean values for :report_changes" do
      assert %Kino.Control{attrs: %{report_changes: %{name: true}}} =
               Kino.Control.form([name: Kino.Input.text("Name")], report_changes: true)
    end
  end

  describe "subscribe/2" do
    test "subscribes to control events" do
      button = Kino.Control.button("Name")

      Kino.Control.subscribe(button, :name)

      info = %{origin: "client1"}
      send(button.attrs.destination, {:event, button.attrs.ref, info})

      assert_receive {:name, ^info}
    end
  end

  describe "stream/1" do
    test "raises on invalid argument" do
      assert_raise ArgumentError,
                   "expected source to be either %Kino.Control{}, %Kino.Input{} or {:interval, ms}, got: 10",
                   fn ->
                     Kino.Control.stream(10)
                   end
    end

    test "returns control event feed" do
      button = Kino.Control.button("Name")

      spawn(fn ->
        Process.sleep(1)
        info = %{origin: "client1"}
        send(button.attrs.destination, {:event, button.attrs.ref, info})
        send(button.attrs.destination, {:event, button.attrs.ref, info})
      end)

      events = button |> Kino.Control.stream() |> Enum.take(2)

      assert events == [%{origin: "client1"}, %{origin: "client1"}]
    end

    test "supports interval" do
      events = 1 |> Kino.Control.interval() |> Kino.Control.stream() |> Enum.take(2)
      assert events == [%{type: :interval, iteration: 0}, %{type: :interval, iteration: 1}]
    end

    test "halts when the topic is cleared" do
      button = Kino.Control.button("Name")

      spawn(fn ->
        Process.sleep(1)
        info = %{origin: "client1"}
        send(button.attrs.destination, {:event, button.attrs.ref, info})
        send(button.attrs.destination, {:clear_topic, button.attrs.ref})
      end)

      events = button |> Kino.Control.stream() |> Enum.to_list()
      assert events == [%{origin: "client1"}]
    end
  end

  describe "stream/1 with a list of sources" do
    test "raises on invalid source" do
      assert_raise ArgumentError,
                   "expected source to be either %Kino.Control{}, %Kino.Input{} or {:interval, ms}, got: 10",
                   fn ->
                     Kino.Control.stream([10])
                   end
    end

    test "returns combined event feed for the given sources" do
      button = Kino.Control.button("Click")
      input = Kino.Input.text("Name")

      spawn(fn ->
        Process.sleep(1)
        info = %{origin: "client1"}
        send(button.attrs.destination, {:event, button.attrs.ref, info})
        send(button.attrs.destination, {:event, input.attrs.ref, info})
      end)

      events = [button, input] |> Kino.Control.stream() |> Enum.take(2)

      assert events == [%{origin: "client1"}, %{origin: "client1"}]
    end
  end

  describe "stream/2" do
    test "runs the given function on each event" do
      button = Kino.Control.button("Click")

      myself = self()

      Kino.Control.stream(button, fn event ->
        send(myself, event)
      end)

      Process.sleep(1)
      info = %{origin: "client1"}
      send(button.attrs.destination, {:event, button.attrs.ref, info})
      send(button.attrs.destination, {:event, button.attrs.ref, info})

      assert_receive ^info
      assert_receive ^info
    end
  end

  describe "stream/3" do
    test "reduces state over subsequent events" do
      button = Kino.Control.button("Click")

      myself = self()

      Kino.Control.stream(button, 0, fn _event, counter ->
        send(myself, {:counter, counter + 1})
        counter + 1
      end)

      Process.sleep(1)
      info = %{origin: "client1"}
      send(button.attrs.destination, {:event, button.attrs.ref, info})
      send(button.attrs.destination, {:event, button.attrs.ref, info})

      assert_receive {:counter, 1}
      assert_receive {:counter, 2}
    end
  end

  describe "tagged_stream/1" do
    test "raises on invalid argument" do
      assert_raise ArgumentError, "expected a keyword list, got: [0]", fn ->
        Kino.Control.tagged_stream([0])
      end

      assert_raise ArgumentError,
                   "expected source to be either %Kino.Control{}, %Kino.Input{} or {:interval, ms}, got: 10",
                   fn ->
                     Kino.Control.tagged_stream(name: 10)
                   end
    end

    test "returns tagged event feed for the given sources" do
      button = Kino.Control.button("Click")
      input = Kino.Input.text("Name")

      spawn(fn ->
        Process.sleep(1)
        info = %{origin: "client1"}
        send(button.attrs.destination, {:event, button.attrs.ref, info})
        send(input.attrs.destination, {:event, input.attrs.ref, info})
      end)

      events =
        [click: button, name: input]
        |> Kino.Control.tagged_stream()
        |> Enum.take(2)

      assert events == [{:click, %{origin: "client1"}}, {:name, %{origin: "client1"}}]
    end
  end

  describe "tagged_stream/2" do
    test "runs the given function on each event" do
      button = Kino.Control.button("Click")
      input = Kino.Input.text("Name")

      myself = self()

      Kino.Control.tagged_stream([click: button, name: input], fn pair ->
        send(myself, pair)
      end)

      Process.sleep(1)
      info = %{origin: "client1"}
      send(button.attrs.destination, {:event, button.attrs.ref, info})
      send(input.attrs.destination, {:event, input.attrs.ref, info})

      assert_receive {:click, ^info}
      assert_receive {:name, ^info}
    end
  end

  describe "tagged_stream/3" do
    test "reduces state over subsequent events" do
      up = Kino.Control.button("Up")
      down = Kino.Control.button("Down")

      myself = self()

      Kino.Control.tagged_stream([up: up, down: down], 0, fn
        {:up, _event}, counter ->
          send(myself, {:counter, counter + 1})
          counter + 1

        {:down, _event}, counter ->
          send(myself, {:counter, counter - 1})
          counter - 1
      end)

      Process.sleep(1)
      info = %{origin: "client1"}
      send(up.attrs.destination, {:event, up.attrs.ref, info})
      send(up.attrs.destination, {:event, up.attrs.ref, info})
      send(down.attrs.destination, {:event, down.attrs.ref, info})
      send(down.attrs.destination, {:event, down.attrs.ref, info})

      assert_receive {:counter, 1}
      assert_receive {:counter, 2}
      assert_receive {:counter, 1}
      assert_receive {:counter, 0}
    end
  end
end
