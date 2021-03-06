#
# Wire
# Copyright (C) 2016 Wire Swiss GmbH
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see http://www.gnu.org/licenses/.
#

window.z ?= {}
z.conversation ?= {}

# Conversation service for all conversation calls to the backend REST API.
class z.conversation.ConversationService
  URL_CONVERSATIONS: '/conversations'
  ###
  Construct a new Conversation Service.

  @param client [z.service.Client] Client for the API calls
  ###
  constructor: (@client, @storage_service) ->
    @logger = new z.util.Logger 'z.conversation.ConversationService', z.config.LOGGER.OPTIONS

  ###
  Saves a conversation entity in the local database.

  @param conversation_et [z.entity.Conversation] Conversation entity
  @return [Promise<String>] Promise that will resolve with the primary key of the persisted conversation entity
  ###
  _save_conversation_in_db: (conversation_et) ->
    return new Promise (resolve, reject) =>
      store_name = @storage_service.OBJECT_STORE_CONVERSATIONS
      @storage_service.save store_name, conversation_et.id, conversation_et.serialize()
      .then (primary_key) =>
        @logger.log @logger.levels.INFO, "Conversation '#{primary_key}' was stored for the first time"
        resolve conversation_et
      .catch (error) =>
        @logger.log @logger.levels.ERROR, "Conversation '#{conversation_et.id}' could not be stored", error
        reject error

  ###
  Updates a conversation entity in the database.

  @param updated_field [z.conversation.ConversationUpdateType] Property of the conversation entity which needs to be updated in the local database
  @return [Promise<String|z.entity.Conversation>] Promise which resolves with the conversation entity (if update was successful) or the conversation entity (if it was a new entity)
  ###
  _update_conversation_in_db: (conversation_et, updated_field) ->
    return new Promise (resolve, reject) =>
      store_name = @storage_service.OBJECT_STORE_CONVERSATIONS

      switch updated_field
        when z.conversation.ConversationUpdateType.ARCHIVED_STATE
          entity =
            archived_state: conversation_et.archived_state()
            archived_timestamp: conversation_et.archived_timestamp()
        when z.conversation.ConversationUpdateType.CLEARED_TIMESTAMP
          entity = cleared_timestamp: conversation_et.cleared_timestamp()
        when z.conversation.ConversationUpdateType.LAST_EVENT_TIMESTAMP
          entity = last_event_timestamp: conversation_et.last_event_timestamp()
        when z.conversation.ConversationUpdateType.LAST_READ_TIMESTAMP
          entity = last_read_timestamp: conversation_et.last_read_timestamp()
        when z.conversation.ConversationUpdateType.MUTED_STATE
          entity =
            muted_state: conversation_et.muted_state()
            muted_timestamp: conversation_et.muted_timestamp()

      @storage_service.update store_name, conversation_et.id, entity
      .then (number_of_updated_records) =>
        if number_of_updated_records
          @logger.log @logger.levels.INFO,
            "Conversation '#{conversation_et.id}' got a persistent update for property '#{updated_field}'"
          resolve conversation_et
        else
          @_save_conversation_in_db conversation_et
      .catch (error) =>
        @logger.log @logger.levels.ERROR, "Conversation '#{conversation_et.id}' could not be updated", error
        reject error

  ###############################################################################
  # Create conversations
  ###############################################################################

  ###
  Create a new conversation.

  @note Supply at least 2 user IDs! Do not include the requestor
  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/createGroupConversation

  @param user_ids [Array<String>] IDs of users (excluding the requestor) to be part of the conversation
  @param name [String] User defined name for the Conversation (optional)
  @param callback [Function] Function to be called on server return
  ###
  create_conversation: (user_ids, name, callback) ->
    @client.send_json
      url: @client.create_url z.conversation.ConversationService::URL_CONVERSATIONS
      type: 'POST'
      data:
        users: user_ids
        name: name
      callback: callback

  ###
  Create a One:One conversation.

  @note Do not include the requestor
  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/createOne2OneConversation

  @param user_ids [Array<String>] IDs of users (excluding the requestor) to be part of the conversation
  @param name [String] User defined name for the Conversation (optional)
  @param callback [Function] Function to be called on server return
  ###
  create_one_to_one_conversation: (user_ids, name, callback) ->
    @client.send_json
      url: @client.create_url '/conversations/one2one'
      type: 'POST'
      data:
        users: user_ids
        name: name
      callback: callback

  ###############################################################################
  # Get conversations
  ###############################################################################

  ###
  Retrieves meta information about all the conversations of a user.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/conversations

  @param limit [Integer] Number of results to return (default 100, max 100)
  @param conversation_id [String] Conversation ID to start from
  ###
  get_conversations: (limit = 100, conversation_id = undefined) ->
    @client.send_request
      url: @client.create_url z.conversation.ConversationService::URL_CONVERSATIONS
      type: 'GET'
      data:
        size: limit
        start: conversation_id

  ###
  Get a conversation by ID.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/conversation

  @param conversation_id [String] ID of conversation to get
  @param callback [Function] Function to be called on server return
  ###
  get_conversation_by_id: (conversation_id, callback) ->
    @client.send_request
      url: @client.create_url "/conversations/#{conversation_id}"
      type: 'GET'
      callback: callback

  ###
  Get the last (i.e. most current) event ID per conversation.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/lastEvents
  @todo Implement paging for this endpoint

  @param callback [Function] Function to be called on server return
  ###
  get_last_events: (callback) ->
    @client.send_request
      url: @client.create_url '/conversations/last-events'
      type: 'GET'
      callback: callback

  ###############################################################################
  # Send events
  ###############################################################################

  ###
  Remove member from conversation.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/removeMember

  @param conversation_id [String] ID of conversation to remove member from
  @param user_id [String] ID of member to be removed from the the conversation
  @param callback [Function] Function to be called on server return
  ###
  delete_members: (conversation_id, user_id, callback) ->
    @client.send_request
      url: @client.create_url "/conversations/#{conversation_id}/members/#{user_id}"
      type: 'DELETE'
      callback: callback

  ###
  Delete events from a conversation.

  @param message_id [String] ID of conversation to remove message from
  @param primary_key [String] ID of the actual message
  @return [Promise] Resolves with the number of deleted records
  ###
  delete_message_from_db: (conversation_id, message_id) ->
    @storage_service.db[@storage_service.OBJECT_STORE_CONVERSATION_EVENTS]
    .where 'raw.conversation'
    .equals conversation_id
    .and (record) -> record.mapped?.id is message_id
    .delete()

  ###
  Delete events from a conversation.

  @param conversation_id [String] delete message for this conversation
  ###
  delete_messages_from_db: (conversation_id) ->
    @storage_service.db[@storage_service.OBJECT_STORE_CONVERSATION_EVENTS]
    .where 'raw.conversation'
    .equals conversation_id
    .delete()

  ###
  Update events timestamp.

  @param primary_key [String] Primary key used to find an event in the database
  @param timestamp [Number]
  ###
  update_message_timestamp_in_db: (primary_key, timestamp) ->
    updated_record = undefined
    Promise.resolve()
    .then ->
      if not timestamp?
        throw new TypeError 'Missing timestamp'
    .then =>
      @storage_service.load @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key
    .then (record) =>
      record.mapped.data.edited_time = record.mapped.time
      record.mapped.time = record.raw.time = new Date(timestamp).toISOString()
      record.meta.timestamp = timestamp
      updated_record = record
      @storage_service.update @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key, record
    .then =>
      @logger.log 'Updated message_et timestamp', primary_key
      return updated_record

  ###
  Delete events from a conversation.

  @param primary_key [String] Primary key used to find an event in the database
  ###
  update_asset_as_uploaded_in_db: (primary_key, asset_data) ->
    @storage_service.load @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key
    .then (record) =>
      record.mapped.data.id = asset_data.id
      record.mapped.data.otr_key = asset_data.otr_key
      record.mapped.data.sha256 = asset_data.sha256
      record.mapped.data.status = z.assets.AssetTransferState.UPLOADED
      @storage_service.update @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key, record
    .then =>
      @logger.log 'Updated asset message_et (uploaded)', primary_key

  ###
  Delete events from a conversation.

  @param primary_key [String] Primary key used to find an event in the database
  ###
  update_asset_preview_in_db: (primary_key, asset_data) ->
    @storage_service.load @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key
    .then (record) =>
      record.mapped.data.preview_id = asset_data.id
      record.mapped.data.preview_otr_key = asset_data.otr_key
      record.mapped.data.preview_sha256 = asset_data.sha256
      @storage_service.update @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key, record
    .then =>
      @logger.log 'Updated asset message_et (preview)', primary_key

  ###
  Delete events from a conversation.

  @param primary_key [String] Primary key used to find an event in the database
  ###
  update_asset_as_failed_in_db: (primary_key, reason) ->
    @storage_service.load @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key
    .then (record) =>
      record.mapped.data.status = z.assets.AssetTransferState.UPLOAD_FAILED
      record.mapped.data.reason = reason
      @storage_service.update @storage_service.OBJECT_STORE_CONVERSATION_EVENTS, primary_key, record
    .then =>
      @logger.log 'Updated asset message_et (failed)', primary_key

  ###
  Loads conversation states from the local database.

  ###
  load_conversation_states_from_db: =>
    return new Promise (resolve, reject) =>
      @storage_service.get_all @storage_service.OBJECT_STORE_CONVERSATIONS
      .then (conversation_states) =>
        @logger.log @logger.levels.INFO, "Loaded '#{conversation_states.length}' local conversation states", conversation_states
        resolve conversation_states
      .catch (error) =>
        @logger.log @logger.levels.ERROR, 'Failed to load local conversation states', error
        reject error

  ###
  Load conversation event.

  @param conversation_id [String] ID of conversation
  @param message_id [String]
  ###
  load_event_from_db: (conversation_id, message_id) ->
    return new Promise (resolve, reject) =>
      @storage_service.db[@storage_service.OBJECT_STORE_CONVERSATION_EVENTS]
      .where 'raw.conversation'
      .equals conversation_id
      .filter (record) -> record.mapped?.id is message_id
      .first()
      .then (record) ->
        resolve record
      .catch (error) =>
        @logger.log @logger.levels.ERROR,
          "Failed to get event for conversation '#{conversation_id}': #{error.message}", error
        reject error

  ###
  Load conversation events.

  @param conversation_id [String] ID of conversation
  @param offset [String] Timestamp that loaded events have to undercut
  @param limit [Number] Amount of events to load
  @return [Promise] Promise that resolves with the retrieved records ([events, has_further_events])
  ###
  load_events_from_db: (conversation_id, offset, limit = z.config.MESSAGES_FETCH_LIMIT) ->
    return new Promise (resolve, reject) =>
      @storage_service.db[@storage_service.OBJECT_STORE_CONVERSATION_EVENTS]
      .where 'raw.conversation'
      .equals conversation_id
      .reverse()
      .sortBy 'meta.timestamp'
      .then (records) ->
        records = (record for record in records when record.meta.timestamp < offset) if offset
        has_further_events = records.length > limit
        resolve [records.slice(0, limit), has_further_events]
      .catch (error) =>
        @logger.log @logger.levels.ERROR,
          "Failed to get events for conversation '#{conversation_id}': #{error.message}", error
        reject error

  ###
  Load all unread events of a conversation.

  @param conversation_et [z.entity.Conversation] Conversation entity
  @param offset [String] Timestamp that loaded events have to undercut
  @return [Promise] Promise that resolves with the retrieved records
  ###
  load_unread_events_from_db: (conversation_et, offset) ->
    return new Promise (resolve, reject) =>
      conversation_id = conversation_et.id
      @storage_service.db[@storage_service.OBJECT_STORE_CONVERSATION_EVENTS]
      .where 'raw.conversation'
      .equals conversation_id
      .reverse()
      .sortBy 'raw.time'
      .then (records) ->
        records = (record for record in records when record.meta.timestamp < offset) if offset
        records = (record for record in records when record.meta.timestamp > conversation_et.last_read_timestamp())
        resolve records
      .catch (error) =>
        @logger.log @logger.levels.ERROR,
          "Failed to get unread events for conversation '#{conversation_et.id}': #{error.message}", error
        reject error

  ###
  Add users to an existing conversation.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/addMembers

  @param conversation_id [String] ID of conversation to add users to
  @param user_ids [Array<String>] IDs of users to be added to the conversation
  @return [Promise] Promise that resolves with the server response
  ###
  post_members: (conversation_id, user_ids) ->
    @client.send_json
      url: @client.create_url "/conversations/#{conversation_id}/members"
      type: 'POST'
      data:
        users: user_ids

  ###
  Post an encrypted message to a conversation.
  @note If "recipients" are not specified you will receive a list of all missing OTR recipients (user-client-map).
  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/postOtrMessage
  @example How to send "recipients" payload
  "recipients": {
    "<user-id>": {
      "<client-id>": "<base64-encoded-encrypted-content>"
    }
  }

  @param conversation_id [String] ID of conversation to send message in
  @param payload [Object] Payload to be posted
  @option [OtrRecipients] recipients Map with per-recipient data
  @option [String] sender Client ID of the sender
  @param force_sending [Boolean] Should the backend ignore missing clients
  @return [Promise] Promise that resolve when the message was sent
  ###
  post_encrypted_message: (conversation_id, payload, force_sending) ->
    url = @client.create_url "/conversations/#{conversation_id}/otr/messages"
    url = "#{url}?ignore_missing=true" if force_sending

    @client.send_json
      url: url
      type: 'POST'
      data: payload

  ###
  Saves or updates a conversation entity in the local database.

  @param conversation_et [z.entity.Conversation] Conversation entity
  @param updated_field [z.conversation.ConversationUpdateType] Property of the conversation entity which needs to be updated in the local database
  @return [Promise<String|z.entity.Conversation>] Promise which resolves with the conversation entity (if update was successful) or the conversation entity (if it was a new entity)
  ###
  save_conversation_in_db: (conversation_et, updated_field) =>
    if updated_field
      @_update_conversation_in_db conversation_et, updated_field
    else
      @_save_conversation_in_db conversation_et

  ###
  Update conversation properties.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/updateConversation

  @param conversation_id [String] ID of conversation to rename
  @param name [String] New conversation name
  @param callback [Function] Function to be called on server return
  ###
  update_conversation_properties: (conversation_id, name, callback) ->
    @client.send_json
      url: @client.create_url "/conversations/#{conversation_id}"
      type: 'PUT'
      data:
        name: name
      callback: callback

  ###
  Update self membership properties.

  @see https://staging-nginz-https.zinfra.io/swagger-ui/#!/conversations/updateSelf

  @param conversation_id [String] ID of conversation to update
  @param payload [Object] Updated properties
  @param callback [Function] Function to be called on server return
  ###
  update_member_properties: (conversation_id, payload, callback) ->
    @client.send_json
      url: @client.create_url "/conversations/#{conversation_id}/self"
      type: 'PUT'
      data: payload
      callback: (response, error) ->
        if callback?
          callback
            conversation: conversation_id
            data: data
          , error
