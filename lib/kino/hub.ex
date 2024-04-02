defmodule Kino.Hub do
  @moduledoc """
  Functions related to hub integrations and Livebook apps.
  """

  @type app_info ::
          %{type: :single}
          | %{:type => :multi, optional(:started_by) => user_info()}
          | %{type: :none}

  @type user_info :: %{
          id: String.t(),
          name: String.t() | nil,
          email: String.t() | nil,
          source: atom(),
          payload: map() | nil
        }

  @doc """
  Returns information about the running app.

  Note that `:started_by` information is only available for multi-session
  apps when the app uses a Livebook Teams hub.

  Unless called from withing an app deployment, returns `%{type: :none}`.
  """
  @spec app_info() :: app_info()
  def app_info() do
    case Kino.Bridge.get_app_info() do
      {:ok, app_info} -> app_info
      {:error, _} -> %{type: :none}
    end
  end

  @doc """
  Returns user information for the given connected client id.

  Note that this information is only available when the session uses
  Livebook Teams hub, otherwise `:not_available` error is returned.

  If there is no such connected client, `:not_found` error is returned.
  """
  @spec user_info(String.t()) :: {:ok, user_info()} | {:error, :not_found | :not_available}
  def user_info(client_id) do
    case Kino.Bridge.get_user_info(client_id) do
      {:ok, user_info} ->
        {:ok, user_info}

      {:error, reason} when reason in [:not_found, :not_available] ->
        {:error, reason}

      {:error, reason} ->
        raise "failed to access user info, reason: #{inspect(reason)}"
    end
  end
end
