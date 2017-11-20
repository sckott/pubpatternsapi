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

  # make html files of content type text/html
  configure do
    mime_type :apidocs, 'text/html'
  end

  before '/api/*' do
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

    # puts '[env]'
    # p env
    # puts '[Params]'
    # p params

  end

  # after do
  #   # cache response in redis
  #   if $config['caching'] && !response.headers['Cache-Hit'] && response.status == 200
  #     $redis.set(@cache_key, response.body[0], ex: $config['caching']['expires'])
  #   end
  # end

  # prohibit HTTP methods
  route :put, :post, :delete, :copy, :options, :trace, '/*' do
    halt 405
  end


  # handler - redirects any /foo -> /foo/
  #  - if has any query params, passes to handler as before
  get %r{(/.*[^\/])} do
    if request.query_string == "" or request.query_string.nil?
      redirect request.script_name + "#{params[:captures].first}/"
    else
      pass
    end
  end

  # home
  get '/?' do
    content_type :apidocs
    send_file File.join(settings.public_folder, 'index.html')
  end


  # doi
  ## FIXME - not figured out how to regex on doi's only for browser use case
  # get '/*' do
  # # get %r{/10\..+/} do
  # # get /(10\..+)/ do
  #   headers "Access-Control-Allow-Methods" => "HEAD, GET"
  #   headers "Access-Control-Allow-Origin" => "*"
  #   cache_control :public, :must_revalidate, :max_age => 300

  #   out = fetch_download
  #   redirect to(out), 301

  #   # doi = params[:splat].first

  #   # redirect '/api/fetch/#{doi}'
  #   # return MultiJson.dump({
  #   #   "doi" => doi
  #   # })
  # end

  # api -> heartbeat
  get '/api/?' do
    redirect '/api/heartbeat/', 301
  end

  # heartbeat -> /api/heartbeat
  get '/heartbeat/?' do
    redirect '/api/heartbeat/', 301
  end

  get "/api/heartbeat/?" do
    return MultiJson.dump({
      "routes" => [
        "/ (api docs)",
        "/api (-> /api/heartbeat)",
        "/api/heartbeat",
        "/:doi (not working yet)",
        "/api/members",
        "/api/members/:member",
        "/api/prefixes",
        "/api/prefixes/:prefix",
        "/api/doi/*",
        "/api/fetch/*"
      ]
    })
  end



  # members
  get '/api/members/?' do
    res = fetch_members
    return MultiJson.dump(res)
  end

  get '/api/members/:member/?' do
    res = fetch_pattern_member
    return MultiJson.dump(res)
  end


  # prefixes
  get '/api/prefixes/?' do
    res = fetch_prefixes
    return MultiJson.dump(res)
  end

  get '/api/prefixes/:prefix/?' do
    res = fetch_pattern_prefix
    return MultiJson.dump(res)
  end


  # doi
  get '/api/doi/*/?' do
    return MultiJson.dump(fetch_url)
  end


  # fetch/download
  get '/api/fetch/*/?' do
    out = fetch_download
    redirect to(out), 301
  end

end
