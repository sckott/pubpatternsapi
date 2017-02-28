require "rubygems"
require "sinatra"
require "multi_json"
require "yaml"
require "sinatra/multi_route"
# require "redis"

require_relative 'utils'

$config = YAML::load_file(File.join(__dir__, 'config.yaml'))

# $redis = Redis.new host: ENV.fetch('REDIS_PORT_6379_TCP_ADDR', 'localhost'),
#                    port: ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)


class PubPatternsApp < Sinatra::Application
  register Sinatra::MultiRoute

  not_found do
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'an error occurred' })
  end

  not_found do
    halt 404, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'route not found' })
  end

  error 500 do
    halt 500, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'server error' })
  end

  before do
    # pass if %w[fetch].include? request.path_info.split('/')[3]

    headers "Content-Type" => "application/json; charset=utf8"
    headers "Access-Control-Allow-Methods" => "HEAD, GET"
    headers "Access-Control-Allow-Origin" => "*"
    cache_control :public, :must_revalidate, :max_age => 300

    # if $config['caching']
    #   @cache_key = Digest::MD5.hexdigest(request.url)
    #   if $redis.exists(@cache_key)
    #     headers 'Cache-Hit' => 'true'
    #     halt 200, $redis.get(@cache_key)
    #   end
    # end
  end

  # after do
  #   puts request.path_info.split('/')[3]
  #   pass if %w[fetch].include? request.path_info.split('/')[3]

  #   # cache response in redis
  #   if $config['caching'] && !response.headers['Cache-Hit'] && response.status == 200
  #     $redis.set(@cache_key, response.body[0], ex: $config['caching']['expires'])
  #   end
  # end

  # prohibit certain methods
  route :put, :post, :delete, :copy, :options, :trace, '/*' do
    halt 405
  end

  get '/' do
    redirect '/heartbeat/', 301
  end

  get "/heartbeat/?" do
    return MultiJson.dump({
      "routes" => [
        "/heartbeat",
        "/patterns/member/:member",
        "/patterns/prefix/:member",
        "/doi/*",
        "/fetch/*"
      ]
    })
  end

  get '/patterns/member/:member/?' do
    res = fetch_pattern_member
    return MultiJson.dump(res)
  end

  get '/patterns/prefix/:prefix/?' do
    res = fetch_pattern_prefix
    return MultiJson.dump(res)
  end

  get '/doi/*/?' do
    MultiJson.dump(fetch_url)
  end

  get '/fetch/*/?' do
    x = fetch_url
    redirect to(x["url"]), 301
  end

end
