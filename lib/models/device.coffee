async  = require 'async'
bcrypt = require 'bcrypt'
_      = require 'lodash'
debug  = require('debug')('meshblu:model:device')

class Device
  constructor: (attributes={}, dependencies={}) ->
    @devices = dependencies.database?.devices ? require('../database').devices
    @getGeo = dependencies.getGeo ? require('../getGeo')
    @generateToken = dependencies.generateToken ? require('../generateToken')
    @clearCache = dependencies.clearCache ? require '../clearCache'
    @set attributes
    {@uuid} = attributes

  fetch: (callback=->) =>
    if @fetch.cache?
      return _.defer callback, null, @fetch.cache

    @devices.findOne uuid: @uuid, (error, device) =>
      @fetch.cache = device
      unless device?
        error = new Error('Device not found')
      callback error, @fetch.cache

  storeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      bcrypt.hash token, 8, (error, hashedToken) =>
        return callback error if error?

        @attributes.tokens = attributes.tokens ? []

        unless _.any(@attributes.tokens, hash: hashedToken)
          @attributes.tokens.push hash: hashedToken, createdAt: new Date()

        @save callback

  revokeToken: (token, callback=_.noop)=>
    @fetch (error, attributes) =>
      return callback error if error?

      @attributes.tokens = _.reject attributes.tokens, (data) =>
        bcrypt.compareSync token, data.hash

      @save callback

  sanitize: (params) =>
    return params unless _.isObject(params) || _.isArray(params)

    return _.map params, @sanitize if _.isArray params

    params = _.omit params, (value, key) -> key[0] == '$'
    return _.mapValues params, @sanitize

  save: (callback=->) =>
    return callback @error unless @validate()
    async.series [
      @addGeo
      @addHashedToken
      @addOnlineSince
    ], (error) =>
      return callback error if error?
      debug 'save', @attributes
      @devices.update {uuid: @uuid}, {$set: @attributes}, (error, data) =>
        @clearCache @uuid
        callback error

  set: (attributes)=>
    @attributes ?= {}
    @attributes = _.extend {}, @attributes, @sanitize(attributes)
    @attributes.online = !!@attributes.online if @attributes.online?
    @attributes.timestamp = new Date()

  validate: =>
    if @attributes.uuid? && @uuid != @attributes.uuid
      @error = new Error('Cannot modify uuid')
      return false

    return true

  update: (params, callback=->) =>
    params = _.cloneDeep params

    keys = _.keys(params)

    if _.all(keys, (key) -> _.startsWith key, '$')
      params['$set'] ?= {}
      params['$set'].uuid = @uuid
    else
      params.uuid = @uuid

    @devices.update uuid: @uuid, params, (error) =>
      return callback @sanitizeError(error) if error?
      callback()

  addGeo: (callback=->) =>
    return _.defer callback unless @attributes.ipAddress?

    @getGeo @attributes.ipAddress, (error, geo) =>
      @attributes.geo = geo
      callback()

  addHashedToken: (callback=->) =>
    token = @attributes.token
    return _.defer callback, null, null unless token?

    @fetch (error, device) =>
      return callback error if error?
      return callback null, null if device.token == token

      bcrypt.hash token, 8, (error, hashedToken) =>
        @attributes.token = hashedToken if hashedToken?
        callback error

  addOnlineSince: (callback=->) =>
    @fetch (error, device) =>
      return callback error if error?

      if !device.online && @attributes.online
        @attributes.onlineSince = new Date()

      callback()

  sanitizeError: (error) =>
    message = error
    message = error.message if _.isError error

    new Error message.replace("MongoError: ")

module.exports = Device
