defmodule Kino.FS do
  @moduledoc """
  Provides access to notebook files.
  """

  defmodule ForbiddenError do
    @moduledoc """
    Exception raised when access to a notebook file is forbidden.
    """

    defexception [:name]

    @impl true
    def message(exception) do
      "forbidden access to file #{inspect(exception.name)}"
    end
  end

  @doc """
  Accesses notebook file with the given name and returns a local path
  to ead its contents from.

  This invocation may take a while, in case the file is downloaded
  from a URL and is not in the cache.

  > #### File operations {: .info}
  >
  > You should treat the file as read-only. To avoid unnecessary
  > copies the path may potentially be pointing to the original file,
  > in which case any write operations would be persisted. This
  > behaviour is not always the case, so you should not rely on it
  > either.
  """
  @spec file_path(String.t()) :: String.t()
  def file_path(name) when is_binary(name) do
    case Kino.Bridge.get_file_entry_path(name) do
      {:ok, path} ->
        path

      {:error, :forbidden} ->
        raise ForbiddenError, name: name

      {:error, message} when is_binary(message) ->
        raise message

      {:error, reason} when is_atom(reason) ->
        raise "failed to access file path, reason: #{inspect(reason)}"
    end
  end

  @typep file_spec ::
           %{
             type: :local,
             path: String.t()
           }
           | %{
               type: :url,
               url: String.t()
             }
           | %{
               type: :s3,
               bucket_url: String.t(),
               region: String.t(),
               access_key_id: String.t(),
               secret_access_key: String.t(),
               key: String.t()
             }

  @typep fss_entry :: FSS.Local.Entry.t() | FSS.S3.Entry.t() | FSS.HTTP.Entry.t()

  @doc false
  @spec file_spec(String.t()) :: fss_entry()
  def file_spec(name) do
    case Kino.Bridge.get_file_entry_spec(name) do
      {:ok, spec} ->
        file_spec_to_fss(spec)

      {:error, :forbidden} ->
        raise ForbiddenError, name: name

      {:error, message} when is_binary(message) ->
        raise message

      {:error, reason} when is_atom(reason) ->
        raise "failed to access file spec, reason: #{inspect(reason)}"
    end
  end

  @doc false
  @spec file_spec_to_fss(file_spec()) ::
          fss_entry()
  def file_spec_to_fss(%{type: :local} = file_spec) do
    %FSS.Local.Entry{path: file_spec.path}
  end

  def file_spec_to_fss(%{type: :url} = file_spec) do
    case FSS.HTTP.parse(file_spec.url) do
      {:ok, entry} -> entry
      {:error, error} -> raise error
    end
  end

  def file_spec_to_fss(%{type: :s3} = file_spec) do
    case FSS.S3.parse("s3:///" <> file_spec.key,
           config: [
             region: file_spec.region,
             endpoint: file_spec.bucket_url,
             access_key_id: file_spec.access_key_id,
             secret_access_key: file_spec.secret_access_key
           ]
         ) do
      {:ok, entry} -> entry
      {:error, error} -> raise error
    end
  end
end