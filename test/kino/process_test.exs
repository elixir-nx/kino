defmodule Kino.ProcessTest do
  use ExUnit.Case, async: true

  describe "sup_tree/2" do
    test "shows supervision tree with children" do
      {:ok, pid} =
        Supervisor.start_link(
          [
            {Agent, fn -> :ok end},
            %{id: :child, start: {Agent, :start_link, [fn -> :ok end, [name: :agent_child]]}}
          ],
          name: :supervisor_parent,
          strategy: :one_for_one
        )

      [_, {_, agent, _, _}] = Supervisor.which_children(pid)

      content = Kino.Process.sup_tree(pid) |> markdown()
      assert content =~ "0(supervisor_parent):::root ---> 1(agent_child):::worker"
      assert content =~ "0(supervisor_parent):::root ---> 2(#{inspect(agent)}):::worker"

      content = Kino.Process.sup_tree(:supervisor_parent) |> markdown()
      assert content =~ "0(supervisor_parent):::root ---> 1(agent_child):::worker"
      assert content =~ "0(supervisor_parent):::root ---> 2(#{inspect(agent)}):::worker"
    end

    test "shows supervision tree with children alongside non-started children" do
      {:ok, pid} =
        Supervisor.start_link(
          [
            {Agent, fn -> :ok end},
            %{id: :not_started, start: {__MODULE__, :start_ignore, []}}
          ],
          name: :supervisor_parent,
          strategy: :one_for_one
        )

      [{:not_started, :undefined, _, _}, {_, agent, _, _}] = Supervisor.which_children(pid)

      content = Kino.Process.sup_tree(pid) |> markdown()
      assert content =~ "0(supervisor_parent):::root ---> 1(id: :not_started):::notstarted"
      assert content =~ "0(supervisor_parent):::root ---> 2(#{inspect(agent)}):::worker"
    end

    test "raises if supervisor does not exist" do
      assert_raise ArgumentError,
                   ~r/the provided identifier :not_a_valid_supervisor does not reference a running process/,
                   fn -> Kino.Process.sup_tree(:not_a_valid_supervisor) end
    end
  end

  defp markdown(%Kino.Markdown{content: content}), do: content

  def start_ignore, do: :ignore
end
