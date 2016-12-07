fs   = require 'fs'
http = require 'http'
_    = require 'lodash'
path = require 'path'

Redis      = require 'ioredis'
RedisNS    = require '@octoblu/redis-ns'

NOT_FOUND_RESPONSE = {metadata: {code: 404, status: http.STATUS_CODES[404]}}
RATE_LIMIT_TIME = 60 * 15

class MessageHandlers
  constructor: ({redisUri}) ->
    throw new Error("redisUri is required") unless redisUri
    client = new Redis redisUri, dropBufferSupport: true
    client.on 'error', @die
    @redis = new RedisNS "endo-twitter", client

    @jobs = @_getJobs()

  onMessage: ({data, encrypted, metadata}, callback) =>
    job = @jobs[metadata.jobType]
    return callback null, NOT_FOUND_RESPONSE unless job?
    jobType = metadata.jobType
    redisKey = "rate-limit:#{encrypted.id}:#{jobType}"

    @redis.exists redisKey, (error, count) =>
      return callback error if error?
      return @_replyRateLimited jobType, callback if count != 0

      job.action {encrypted}, {data, metadata}, (error, response) =>
        if error?
          return callback error unless error.code == 420
          return @_setRateLimit redisKey, (error, callback) =>
            return callback error if error?
            return @_replyRateLimited jobType, callback

        return callback null, _.pick(response, 'data', 'metadata')

  formSchema: (callback) =>
    callback null, @_formSchemaFromJobs @jobs

  messageSchema: (callback) =>
    callback null, @_messageSchemaFromJobs @jobs

  responseSchema: (callback) =>
    callback null, @_responseSchemaFromJobs @jobs

  _replyRateLimited: (jobType, callback) =>
    error = new Error("#{jobType} has been rate limited")
    error.code = 429
    callback error

  _setRateLimit: (key, callback) =>
    redis.setex key, RATE_LIMIT_TIME, "true", callback

  _formSchemaFromJobs: (jobs) =>
    return {
      message: _.mapValues jobs, 'form'
    }

  _generateMessageMetadata: (jobType) =>
    return {
      type: 'object'
      required: ['jobType']
      properties:
        jobType:
          type: 'string'
          enum: [jobType]
          default: jobType
        respondTo: {}
    }

  _generateResponseMetadata: =>
    return {
      type: 'object'
      required: ['status', 'code']
      properties:
        status:
          type: 'string'
        code:
          type: 'integer'
    }

  _getJobs: =>
    dirnames = fs.readdirSync path.join(__dirname, './jobs')
    jobs = {}
    _.each dirnames, (dirname) =>
      key = _.upperFirst _.camelCase dirname
      dir = path.join 'jobs', dirname
      jobs[key] = require "./#{dir}"
    return jobs

  _messageSchemaFromJob: (job, key) =>
    message = _.cloneDeep job.message
    _.set message, 'x-form-schema.angular', "message.#{key}.angular"
    _.set message, 'x-response-schema', "#{key}"
    _.set message, 'properties.metadata', @_generateMessageMetadata(key)
    message.required = _.union ['metadata'], message.required
    return message

  _messageSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_messageSchemaFromJob

  _responseSchemaFromJob: (job) =>
    response = _.cloneDeep job.response
    _.set response, 'properties.metadata', @_generateResponseMetadata()
    return response

  _responseSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_responseSchemaFromJob

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = MessageHandlers
