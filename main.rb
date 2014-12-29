require 'yaml'
require 'faraday'
require 'daemons'
require 'json'
require 'pp'
require 'docomoru'

class Bot

  def initialize
    set_config
    @connection = Faraday::Connection.new(url: 'https://api.chatwork.com') do |builder|
      builder.use Faraday::Request::UrlEncoded
      builder.use Faraday::Response::Logger
      builder.use Faraday::Adapter::NetHttp
      builder.response :json, :content_type => /\bjson/
    end
    @docomoru_client = Docomoru::Client.new(api_key: @docomo_api_key)
  end

  def set_config
    @app_config = YAML.load_file('./config.yml')
    @chatwork_token = @app_config['chatwork']['token']
    @chatwork_bot_id = @app_config['chatwork']['bot_id']
    @chatwork_room_id = @app_config['chatwork']['room_id']
    @docomo_api_key = @app_config['docomo']['api_key']
  end

  def main
    Daemons.run_proc(File.basename(__FILE__)) do
      loop do
        messages = welcome
        if !messages.nil?
          messages.each do |message|
            reply docomoru_message(message)
          end
        end
        sleep 5
      end
    end
  end

  def welcome
    response = @connection.get do |request|
      request.url "/v1/rooms/#{@chatwork_room_id}/messages?force=0"
      request.headers = {
          'X-ChatWorkToken' => @chatwork_token
      }
    end

    return nil if response.status != 200

    messages = Array.new
    response.body.each do |json|
      messages << json['body'] if json['account']['account_id'] != @chatwork_bot_id
    end

    messages
  end

  def reply(message)
    response = @connection.post do |request|
      request.url "/v1/rooms/#{@chatwork_room_id}/messages"
      request.headers = {
          'X-ChatWorkToken' => @chatwork_token
      }
      request.params[:body] = message
    end
  end

  def docomoru_message(message)
    response = @docomoru_client.create_dialogue(message)
    response.status
    response.body['utt']
  end

end

# `main.rb run` で起動する
bot = Bot.new
bot.main