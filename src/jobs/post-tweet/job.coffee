http    = require 'http'
_       = require 'lodash'
Twitter = require 'twitter'

class PostTweet
  constructor: ({@encrypted}) ->
    @twitter = new Twitter({
      consumer_key:        process.env.ENDO_TWITTER_TWITTER_CLIENT_ID
      consumer_secret:     process.env.ENDO_TWITTER_TWITTER_CLIENT_SECRET
      access_token_key:    @encrypted.secrets.credentials.token
      access_token_secret: @encrypted.secrets.credentials.secret
    })

  do: ({data}, callback) =>
    return callback @_userError(422, 'Status is required') unless data.status?

    @twitter.post 'statuses/update', data, (errors, tweet, response) =>
      if errors?
        error = _.first errors
        error.code = response.code
        return callback error

      return callback null, {
        metadata:
          code: 200
          status: http.STATUS_CODES[200]
        data: tweet
      }

  _userError: (code, message) =>
    error = new Error message
    error.code = code
    return error

module.exports = PostTweet
