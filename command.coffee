_               = require 'lodash'
MeshbluConfig   = require 'meshblu-config'
path            = require 'path'
Endo            = require 'endo-core'
OctobluStrategy = require 'endo-core/octoblu-strategy'
ApiStrategy     = require './src/api-strategy'
MessageHandler  = require './src/message-handler'

MISSING_SERVICE_URL = 'Missing required environment variable: ENDO_TWITTER_SERVICE_URL'
MISSING_MANAGER_URL = 'Missing required environment variable: ENDO_TWITTER_MANAGER_URL'
MISSING_APP_OCTOBLU_HOST = 'Missing required environment variable: APP_OCTOBLU_HOST'
MISSING_REDIS_URI = 'Missing required environment variable: MISSING_REDIS_URI'

class Command
  getOptions: =>
    throw new Error MISSING_SERVICE_URL if _.isEmpty process.env.ENDO_TWITTER_SERVICE_URL
    throw new Error MISSING_MANAGER_URL if _.isEmpty process.env.ENDO_TWITTER_MANAGER_URL
    throw new Error MISSING_APP_OCTOBLU_HOST if _.isEmpty process.env.APP_OCTOBLU_HOST
    throw new Error MISSING_REDIS_URI if _.isEmpty process.env.REDIS_URI


    meshbluConfig   = new MeshbluConfig().toJSON()
    apiStrategy     = new ApiStrategy process.env
    octobluStrategy = new OctobluStrategy process.env, meshbluConfig

    return {
      apiStrategy:     apiStrategy
      deviceType:      'endo:twitter'
      disableLogging:  process.env.DISABLE_LOGGING == "true"
      meshbluConfig:   meshbluConfig
      messageHandler:  new MessageHandler redisUri: process.env.REDIS_URI
      octobluStrategy: octobluStrategy
      port:            process.env.PORT || 80
      appOctobluHost:  process.env.APP_OCTOBLU_HOST
      serviceUrl:      process.env.ENDO_TWITTER_SERVICE_URL
      userDeviceManagerUrl: process.env.ENDO_TWITTER_MANAGER_URL
      staticSchemasPath: process.env.ENDO_TWITTER_STATIC_SCHEMAS_PATH
    }

  run: =>
    server = new Endo @getOptions()
    server.run (error) =>
      throw error if error?

      {address,port} = server.address()
      console.log "Server listening on #{address}:#{port}"

command = new Command()
command.run()
