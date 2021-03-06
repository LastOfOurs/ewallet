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

defmodule EWallet.Web.V1.ActivityLogOverlay do
  @moduledoc """
  Overlay for the ActivityLog schema.
  """

  @behaviour EWallet.Web.V1.Overlay

  def preload_assocs, do: []

  def default_preload_assocs, do: []

  def search_fields,
    do: [
      :id,
      :action,
      :target_identifier,
      :target_type,
      :originator_identifier,
      :originator_type
    ]

  def sort_fields,
    do: [
      :id,
      :action,
      :target_identifier,
      :target_type,
      :originator_identifier,
      :originator_type,
      :inserted_at
    ]

  def self_filter_fields,
    do: [
      :id,
      :action,
      :target_identifier,
      :target_type,
      :originator_identifier,
      :originator_type,
      :inserted_at
    ]

  def filter_fields,
    do: [
      :id,
      :action,
      :target_identifier,
      :target_type,
      :originator_identifier,
      :originator_type,
      :inserted_at
    ]
end
