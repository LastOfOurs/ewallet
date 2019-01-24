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

  @default_page 1
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
  def paginate_attrs(queryable, attrs, allowed_fields \\ [], repo \\ Repo)

  def paginate_attrs(queryable, %{"page" => page} = attrs, _, repo) when not is_integer(page) do
    result = parse_string_param(attrs, "page", page)

    case result do
      %{"page" => _} -> paginate_attrs(queryable, result, [], repo)
      _ -> result
    end
  end

  def paginate_attrs(queryable, %{"per_page" => per_page} = attrs, allowed_fields, repo)
      when not is_integer(per_page) do
    result = parse_string_param(attrs, "per_page", per_page)

    case result do
      %{"start_from" => _} -> paginate_attrs(queryable, result, allowed_fields, repo)
      %{"per_page" => _} -> paginate_attrs(queryable, result, [], repo)
      _ -> result
    end
  end

  def paginate_attrs(_, %{"page" => _, "start_from" => _}, _, _) do
    {:error, :invalid_parameter, "`page` cannot be used with `start_from`"}
  end

  def paginate_attrs(_, %{"page" => page}, _, _) when is_integer(page) and page < 0 do
    {:error, :invalid_parameter, "`page` must be non-negative integer"}
  end

  def paginate_attrs(_, %{"per_page" => per_page}, _, _)
      when is_integer(per_page) and per_page < 1 do
    {:error, :invalid_parameter, "`per_page` must be non-negative, non-zero integer"}
  end

  def paginate_attrs(queryable, attrs, [], repo) do
    page = Map.get(attrs, "page", @default_page)
    per_page = get_per_page(attrs)

    paginate(queryable, %{"page" => page, "per_page" => per_page}, repo)
  end

  def paginate_attrs(
        queryable,
        %{"start_by" => start_by, "start_from" => start_from} = attrs,
        allowed_fields,
        repo
      )
      when is_binary(start_by) do
    per_page = get_per_page(attrs)
    start_by = String.to_atom(start_by)

    paginate_attrs(
      queryable,
      %{
        "per_page" => per_page,
        "start_by" => start_by,
        "start_from" => start_from
      },
      allowed_fields,
      repo
    )
  end

  def paginate_attrs(
        queryable,
        %{
          "per_page" => per_page,
          "start_by" => start_by,
          "start_from" => start_from
        },
        allowed_fields,
        repo
      )
      when is_atom(start_by) do
    case start_by in allowed_fields do
      true ->
        paginate(
          queryable,
          %{
            "per_page" => per_page,
            "start_by" => start_by,
            "start_from" => start_from
          },
          repo
        )

      _ ->
        available_fields = inspect(allowed_fields)

        msg =
          "start_by: `#{start_by}` is not allowed. The available fields are: #{available_fields}"

        {:error, :invalid_parameter, msg}
    end
  end

  def paginate_attrs(queryable, %{"start_from" => _} = attrs, [field | _], repo) do
    # Set default value of `start_by` to the first element in `allowed_fields`
    start_by = Atom.to_string(field)
    attrs = Map.put(attrs, "start_by", start_by)
    paginate_attrs(queryable, attrs, [field], repo)
  end

  def paginate_attrs(_, %{"start_by" => start_by}, _, _)
      when not is_binary(start_by) and not is_atom(start_by) do
    {:error, :invalid_parameter, "`start_by` must be a string"}
  end

  # Try to parse the given string pagination parameter.
  defp parse_string_param(attrs, name, value) do
    case Integer.parse(value, 10) do
      {page, ""} ->
        Map.put(attrs, name, page)

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

  @doc """
  Paginate a query using the given `page` and `per_page` and returns a paginator.
  If a query has `start_from`, then returns a paginator with all records after the specify `start_from`.
  """
  def paginate(queryable, attrs, repo \\ Repo)

  def paginate(queryable, %{"page" => _, "per_page" => _} = attrs, repo) do
    {records, more_page} = fetch(queryable, attrs, repo)

    # Return pagination result
    paginate(attrs, more_page, records)
  end

  def paginate(
        queryable,
        %{
          "start_by" => start_by,
          "start_from" => start_from,
          "start_exist" => true,
          "per_page" => per_page
        },
        repo
      ) do
    {records, more_page} =
      queryable
      |> where([q], field(q, ^start_by) >= ^start_from)
      # effect only when `sort_by` doesn't specify.
      |> order_by([q], field(q, ^start_by))
      |> fetch(
        %{"start_from" => start_from, "page" => 1, "per_page" => per_page},
        repo
      )

    # Return pagination result
    paginate(%{"page" => 1, "per_page" => per_page}, more_page, records)
  end

  def paginate(_, %{"start_exist" => false}, _), do: {:error, :unauthorized}

  def paginate(
        queryable,
        %{
          "start_by" => start_by,
          "start_from" => start_from,
          "per_page" => per_page
        },
        repo
      ) do
    # Verify if the given `start_from` exist to prevent unexpected result.
    target = Map.put(%{}, start_by, start_from)
    exist = repo.get_by(queryable, target) != nil

    paginate(
      queryable,
      %{
        "start_by" => start_by,
        "start_from" => start_from,
        "start_exist" => exist,
        "per_page" => per_page
      },
      repo
    )
  end

  def paginate(%{"page" => page, "per_page" => per_page}, more_page, records)
      when is_list(records) do
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

  def paginate(
        %{
          "start_by" => start_by,
          "start_from" => start_from,
          "per_page" => per_page
        },
        more_page,
        records
      )
      when is_list(records) do
    pagination = %{
      page: 1,
      per_page: per_page,
      start_by: start_by,
      start_from: start_from,
      is_first_page: true,
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
  def fetch(queryable, %{"page" => page, "per_page" => per_page}, repo \\ Repo) do
    # + 1 to see if it is the last page yet
    limit = per_page + 1

    records =
      queryable
      |> get_query_offset(%{"page" => page, "per_page" => per_page})
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
    offset =
      case page do
        n when n > 0 -> (page - 1) * per_page
        _ -> 0
      end

    queryable
    |> offset(^offset)
  end
end
