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

defmodule EWallet.Web.V1.AccountSerializerTest do
  use EWallet.Web.SerializerCase, :v1
  alias Ecto.Association.NotLoaded
  alias EWallet.Web.{Orchestrator, Paginator}
  alias EWallet.Web.V1.{AccountOverlay, AccountSerializer, CategorySerializer}
  alias EWalletDB.Account
  alias ActivityLogger.System
  alias Utils.Helpers.DateFormatter

  describe "AccountSerializer.serialize/1" do
    test "serializes an account into V1 response format" do
      master = :account |> insert()
      category = :category |> insert()
      {:ok, account} = :account |> insert() |> Account.add_category(category, %System{})
      {:ok, account} = Orchestrator.one(account, AccountOverlay)

      assert AccountSerializer.serialize(account) == %{
               object: "account",
               id: account.id,
               socket_topic: "account:#{account.id}",
               parent_id: master.id,
               name: account.name,
               description: account.description,
               master: Account.master?(account),
               category_ids: CategorySerializer.serialize(account.categories, :id),
               categories: CategorySerializer.serialize(account.categories),
               metadata: %{},
               encrypted_metadata: %{},
               avatar: %{
                 original: nil,
                 large: nil,
                 small: nil,
                 thumb: nil
               },
               created_at: DateFormatter.to_iso8601(account.inserted_at),
               updated_at: DateFormatter.to_iso8601(account.updated_at)
             }
    end

    test "serializes a list of accounts into a list object" do
      account1 = :account |> insert() |> Repo.preload([:parent, :categories])
      account2 = :account |> insert() |> Repo.preload([:parent, :categories])

      accounts = [account1, account2]

      expected = %{
        object: "list",
        data: [
          %{
            object: "account",
            id: account1.id,
            socket_topic: "account:#{account1.id}",
            parent_id: nil,
            name: account1.name,
            description: account1.description,
            master: Account.master?(account1),
            category_ids: CategorySerializer.serialize(account1.categories, :id),
            categories: CategorySerializer.serialize(account1.categories),
            metadata: %{},
            encrypted_metadata: %{},
            avatar: %{
              original: nil,
              large: nil,
              small: nil,
              thumb: nil
            },
            created_at: DateFormatter.to_iso8601(account1.inserted_at),
            updated_at: DateFormatter.to_iso8601(account1.updated_at)
          },
          %{
            object: "account",
            id: account2.id,
            socket_topic: "account:#{account2.id}",
            parent_id: account2.parent.id,
            name: account2.name,
            description: account2.description,
            master: Account.master?(account2),
            category_ids: CategorySerializer.serialize(account2.categories, :id),
            categories: CategorySerializer.serialize(account2.categories),
            metadata: %{},
            encrypted_metadata: %{},
            avatar: %{
              original: nil,
              large: nil,
              small: nil,
              thumb: nil
            },
            created_at: DateFormatter.to_iso8601(account2.inserted_at),
            updated_at: DateFormatter.to_iso8601(account2.updated_at)
          }
        ]
      }

      assert AccountSerializer.serialize(accounts) == expected
    end

    test "serializes an account paginator into a list object" do
      account1 = :account |> insert() |> Repo.preload([:parent, :categories])
      account2 = :account |> insert() |> Repo.preload([:parent, :categories])

      paginator = %Paginator{
        data: [account1, account2],
        pagination: %{
          current_page: 9,
          per_page: 7,
          is_first_page: false,
          is_last_page: true
        }
      }

      expected = %{
        object: "list",
        data: [
          %{
            object: "account",
            id: account1.id,
            socket_topic: "account:#{account1.id}",
            parent_id: nil,
            name: account1.name,
            description: account1.description,
            master: Account.master?(account1),
            category_ids: CategorySerializer.serialize(account1.categories, :id),
            categories: CategorySerializer.serialize(account1.categories),
            metadata: %{},
            encrypted_metadata: %{},
            avatar: %{
              original: nil,
              large: nil,
              small: nil,
              thumb: nil
            },
            created_at: DateFormatter.to_iso8601(account1.inserted_at),
            updated_at: DateFormatter.to_iso8601(account1.updated_at)
          },
          %{
            object: "account",
            id: account2.id,
            socket_topic: "account:#{account2.id}",
            parent_id: account2.parent.id,
            name: account2.name,
            description: account2.description,
            master: Account.master?(account2),
            category_ids: CategorySerializer.serialize(account2.categories, :id),
            categories: CategorySerializer.serialize(account2.categories),
            metadata: %{},
            encrypted_metadata: %{},
            avatar: %{
              original: nil,
              large: nil,
              small: nil,
              thumb: nil
            },
            created_at: DateFormatter.to_iso8601(account2.inserted_at),
            updated_at: DateFormatter.to_iso8601(account2.updated_at)
          }
        ],
        pagination: %{
          current_page: 9,
          per_page: 7,
          is_first_page: false,
          is_last_page: true
        }
      }

      assert AccountSerializer.serialize(paginator) == expected
    end

    test "serializes to nil if account is not given" do
      assert AccountSerializer.serialize(nil) == nil
    end

    test "serializes to nil if account is not loaded" do
      assert AccountSerializer.serialize(%NotLoaded{}) == nil
    end

    test "serializes an empty account paginator into a list object" do
      paginator = %Paginator{
        data: [],
        pagination: %{
          current_page: 1,
          per_page: 10,
          is_first_page: true,
          is_last_page: true
        }
      }

      expected = %{
        object: "list",
        data: [],
        pagination: %{
          current_page: 1,
          per_page: 10,
          is_first_page: true,
          is_last_page: true
        }
      }

      assert AccountSerializer.serialize(paginator) == expected
    end
  end

  describe "AccountSerializer.serialize/2" do
    test "serializes accounts to ids" do
      accounts = [account1, account2] = insert_list(2, :account)
      assert AccountSerializer.serialize(accounts, :id) == [account1.id, account2.id]
    end
  end
end
