http    = require 'http'
_       = require 'lodash'
Twitter = require 'twitter'

class PostBlocksDestroy
  constructor: ({@encrypted}) ->
    @twitter = new Twitter({
      consumer_key:        process.env.ENDO_TWITTER_TWITTER_CLIENT_ID
      consumer_secret:     process.env.ENDO_TWITTER_TWITTER_CLIENT_SECRET
      access_token_key:    @encrypted.secrets.credentials.token
      access_token_secret: @encrypted.secrets.credentials.secret
    })

  do: ({data}, callback) =>
    data ?= {}

    @twitter.post 'blocks/destroy', data, (error, data) =>
      return callback error if error?
      return callback null, {
        metadata:
          code: 200
          status: http.STATUS_CODES[200]
        data: data
      }

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PostBlocksDestroy