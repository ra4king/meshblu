util = require "./util"
bcrypt = require "bcrypt"
_ = require "lodash"

class SimpleAuth

  constructor: (@dependencies={}) ->
    @authDevice = @dependencies.authDevice || require './authDevice'

  asyncCallback : (error, result, callback) =>
    _.defer( => callback(error, result))

  checkLists: (fromDevice, toDevice, whitelist, blacklist, openByDefault) =>
    return false if !fromDevice || !toDevice

    return true if toDevice.uuid == fromDevice.uuid

    return true if _.contains whitelist, '*'

    return  _.contains(whitelist, fromDevice.uuid) if whitelist?

    return !_.contains(blacklist, fromDevice.uuid) if blacklist?

    openByDefault

  canDiscover: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null
      
    return @asyncCallback(null, true, callback) if @checkLists fromDevice, toDevice, toDevice?.discoverWhitelist, toDevice?.discoverBlacklist, true
    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    return @asyncCallback(null, false, callback)


  canReceive: (fromDevice, toDevice, callback) =>
    result = @checkLists fromDevice, toDevice, toDevice?.receiveWhitelist, toDevice?.receiveBlacklist, true
    @asyncCallback(null, result, callback)

  canSend: (fromDevice, toDevice, callback) =>
    result = @checkLists fromDevice, toDevice, toDevice?.sendWhitelist, toDevice?.sendBlacklist, true
    @asyncCallback(null, result, callback)

  canConfigure: (fromDevice, toDevice, message, callback) =>
    if _.isFunction message
      callback = message
      message = null

    return @asyncCallback(null, true, callback) if @checkLists fromDevice, toDevice, toDevice?.configureWhitelist, toDevice?.configureBlacklist, false

    return @asyncCallback(null, false, callback) if !fromDevice || !toDevice

    return @asyncCallback(null, true, callback) if fromDevice.uuid == toDevice.uuid

    if toDevice.owner?
      return @asyncCallback(null, true, callback) if toDevice.owner == fromDevice.uuid
    else
      return @asyncCallback(null, true, callback) if util.sameLAN(fromDevice.ipAddress, toDevice.ipAddress)

    if message?.token
      return @authDevice(
        toDevice.uuid
        message.token
        (error, result) =>
          return @asyncCallback(error, false, callback) if error?
          return @asyncCallback(null, result?, callback)
       )

    return @asyncCallback(null, false, callback)

module.exports = SimpleAuth
