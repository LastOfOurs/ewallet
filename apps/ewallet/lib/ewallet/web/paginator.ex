# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule EWallet.Web.Paginator do
  @moduledoc """
  The Paginator allows querying of records by page. It takes in a query, break the query down,
  then selectively query only records that are within the given page's scope.
  """
  import Ecto.Query
  alias EWalletDB.Repo

  @default_per_page 10
  @default_max_per_page 100

  defstruct data: [],
            pagination: %{
              per_page: nil,
              current_page: nil,
              is_first_page: nil,
              is_last_page: nil,
              count: nil
            }

  @doc """
  Paginate a query by attempting to extract `page` and `per_page`
  from the given map of attributes and returns a paginator.

  Note that this function is made to allow an easy passing of user inputs
  without the caller needing any knowledge of the pagination attributes
  (so long as the attribute keys don't conflict). Therefore this function
  expects attribute keys to be strings, not atoms.
  """
  @spec paginate_attrs(Ecto.Query.t() | Ecto.Queryable.t(), map(), Ecto.Repo.t()) ::
          %__MODULE__{} | {:error, :invalid_parameter, String.t()}
  def paginate_attrs(queryable, attrs, repo \\ Repo)

  def paginate_attrs(queryable, %{"page" => page} = attrs, repo) when not is_integer(page) do
    parse_string_param(queryable, attrs, "page", page, repo)
  end

  def paginate_attrs(queryable, %{"per_page" => per_page} = attrs, repo) when not is_integer(per_page) do
    parse_string_param(queryable, attrs, "per_page", per_page, repo)
  end

  def paginate_attrs(queryable, %{"page_record_id" => page_record_id} = attrs, repo) when is_bitstring(page_record_id) do
    per_page = get_per_page(attrs)
    paginate(queryable, %{"page_record_id" => page_record_id, "per_page" => per_page} = attrs, repo)
  end

  def paginate_attrs(_, %{"page" => page}, _repo) when is_integer(page) and page < 0 do
    {:error, :invalid_parameter, "`page` must be non-negative integer"}
  end

  def paginate_attrs(_, %{"per_page" => per_page}, _repo) when is_integer(per_page) and per_page < 1 do
    {:error, :invalid_parameter, "`per_page` must be non-negative, non-zero integer"}
  end

  def paginate_attrs(_, %{"page_record_id" => page_record_id}, _repo) when not is_bitstring(page_record_id) do
    {:error, :invalid_parameter, "`page_record_id` must be a string"}
  end

  def paginate_attrs(queryable, attrs, repo) do
    page = Map.get(attrs, "page", 1)
    per_page = get_per_page(attrs)

    paginate(queryable, %{"page" => page, "per_page" => per_page}, repo)
  end

  # Try to parse the given string pagination parameter.
  defp parse_string_param(queryable, attrs, name, value, repo) do
    case Integer.parse(value, 10) do
      {page, ""} ->
        attrs = Map.put(attrs, name, page)
        paginate_attrs(queryable, attrs, repo)

      :error ->
        {:error, :invalid_parameter, "`#{name}` must be non-negative integer"}
    end
  end

  # Returns the per_page number or default, but never greater than the system's defined limit
  defp get_per_page(attrs) do
    per_page = Map.get(attrs, "per_page", @default_per_page)

    max_per_page =
      case Application.get_env(:ewallet, :max_per_page) do
        nil -> @default_max_per_page
        "" -> @default_max_per_page
        value when is_binary(value) -> String.to_integer(value)
        value when is_integer(value) -> value
      end

    case per_page do
      n when n > max_per_page -> max_per_page
      _ -> per_page
    end
  end

  # @doc """
  # Paginate a query using the given `page_record_id` and `per_page` and returns a paginator.
  # """
  def paginate(queryable, %{"page_record_id" => page_record_id, "per_page" => per_page}, repo) do
    if repo == nil, do: repo = Repo

    {records, more_page} = queryable
    |> where([q], q.id >= ^page_record_id)
    |> fetch(%{"page_record_id" => page_record_id, "page" => 0, "per_page" => per_page}, repo)

    pagination = %{
      per_page: per_page,
      current_page: 1,
      is_first_page: true,
      # It's the last page if there are no more records
      is_last_page: !more_page,
      count: length(records)
    }

    %__MODULE__{data: records, pagination: pagination}
  end

  @doc """
  Paginate a query using the given `page` and `per_page` and returns a paginator.
  """
  def paginate(queryable, %{"page" => page, "per_page" => per_page}, repo \\ Repo) do
    {records, more_page} = fetch(queryable, %{"page" => page, "per_page" => per_page}, repo)
    pagination = %{
      per_page: per_page,
      current_page: page,
      is_first_page: page <= 1,
      # It's the last page if there are no more records
      is_last_page: !more_page,
      count: length(records)
    }

    %__MODULE__{data: records, pagination: pagination}
  end

  @doc """
  Paginate a query by explicitly specifying `page` and `per_page`
  and returns a tuple of records and a flag whether there are more pages.
  """
  def fetch(queryable, attrs, repo \\ Repo) do
    %{"page" => page, "per_page" => per_page} = attrs

    # + 1 to see if it is the last page yet
    limit = per_page + 1

    records =
      queryable
      |> get_query_offset(attrs)
      |> limit(^limit)
      |> repo.all()

    # If an extra record is found, remove last one and inform there is more.
    case Enum.count(records) do
      n when n > per_page ->
        {List.delete_at(records, -1), true}
      _ ->
        {records, false}
    end
  end

  defp get_query_offset(queryable, %{"page" => page, "per_page" => per_page}) do
    offset = case page do
      n when n > 0 -> (page - 1) * per_page
      _ -> 0
    end

    queryable
    |> offset(^offset)
  end

  defp get_query_offset(queryable, %{"page_record_id" => _page_record_id}),
    do: queryable
end
