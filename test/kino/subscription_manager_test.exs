defmodule Kino.SubscriptionManagerTest do
  use ExUnit.Case, async: true

  test "subscribe/3 subscribes to events and attaches custom tag" do
    Kino.SubscriptionManager.subscribe("topic1", self(), :tag)

    event = %{type: :ping}
    send(Kino.SubscriptionManager, {:event, "topic1", event})

    assert_receive {:event, :tag, ^event}
  end

  test "unsubscribe/3 unsubscribes the given process from a topic" do
    Kino.SubscriptionManager.subscribe("topic1", self(), :tag1)
    Kino.SubscriptionManager.subscribe("topic2", self(), :tag2)

    Kino.SubscriptionManager.unsubscribe("topic1", self())

    event = %{type: :ping}
    send(Kino.SubscriptionManager, {:event, "topic1", event})
    send(Kino.SubscriptionManager, {:event, "topic2", event})

    assert_receive {:event, :tag2, ^event}
    refute_received {:event, :tag1, ^event}
  end

  test "clear_topic/3 removes all subscribers for the given topic" do
    Kino.SubscriptionManager.subscribe("topic1", self(), :tag1)
    Kino.SubscriptionManager.subscribe("topic2", self(), :tag2)

    Kino.SubscriptionManager.clear_topic("topic1")

    event = %{type: :ping}
    send(Kino.SubscriptionManager, {:event, "topic1", event})
    send(Kino.SubscriptionManager, {:event, "topic2", event})

    assert_receive {:event, :tag2, ^event}
    refute_received {:event, :tag1, ^event}
  end
end
