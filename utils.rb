require "multi_json"
require "serrano"
require "faraday"
require_relative "member_mapper"
require_relative "prefix_mapper"

# get mapper
def err_member(e)
  return { error: { message: "no mapper for the DOI" } }.to_json
end


# members
def fetch_pattern_member
  path = $member_map[params["member"]]["path"]
  json = MultiJson.load(File.read(path))
  return json
end

def fetch_members
  out = $member_map.collect { |x| MultiJson.load(File.read(x[1]["path"])) }
  return out
end


# prefixes
def fetch_pattern_prefix
  begin
    path = $prefix_map[params["prefix"]]["path"]
    json = MultiJson.load(File.read(path))
    return json
  rescue Exception => e
    halt 404, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'that prefix not supported' })
  end
end

def fetch_prefixes
  out = $prefix_map.collect { |x| MultiJson.load(File.read(x[1]["path"])) }
  return out
end



class String
  def murl
    "http://api.crossref.org/members/" + self
  end
end

class String
  def iurl
    "http://api.crossref.org/journals/" + self
  end
end

def get_ctype(x)
  case x
  when 'pdf'
    ct = 'application/pdf'
  when 'xml'
    ct = 'application/xml'
  end
  return ct
end

def from_ctype(x)
  case x
  when 'pdf'
    ct = 'application/pdf'
  when 'xml'
    ct = 'application/xml'
  end
  return ct
end

def make_links(doi, z, regex)
  out = []
  z.to_a.each do |x|
    out << {
      'url' => x[1] % doi.match(regex),
      'content-type' => get_ctype(x[0])
    }
  end
  return out
end


# by doi
def fetch_url
  doi = params[:splat].first
  # FIXME - sanitize doi and error on invalid inputs

  begin
    x = Serrano.works(ids: doi)
  rescue Exception => e
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => e })
  end

  mem = x[0]['message']['member']
  mem_num = mem.split('/').last

  begin
    memz = $member_map[mem_num]
    path = memz["path"]
    memname = memz["name"]
  rescue Exception => e
    halt 404, err_member(e)
  end

  json = MultiJson.load(File.read(path))

  case mem_num
  when "4374"
    links = make_links(doi, json['journals'][0]['urls'],
      json['journals'][0]['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "4374".murl},
      "issn" => "2050-084X".iurl, "link" => links}
  when "2258"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    links = make_links(doi,
      json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]['urls'],
      json['journals'][0]['components']['doi']['regex']
    )
    return {"doi" => doi, "member" => {"name" => memname, "url" => "2258".murl},
      "issn" => Array(issn).map(&:iurl), "link" => links}
  when "340"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    links = make_links(doi, bit['urls'], bit['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "340".murl},
      "issn" => Array(issn).map(&:iurl), "link" => links}
  when "1968"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    links = []
    json['urls'].each do |x|
      links << {
        'url' => x[1] % [issn,
          res[0]['message']['volume'],
          res[0]['message']['issue'],
          doi.match(json['components']['doi']['regex']).to_s.sub!(/^[0]+/, "")
        ],
        'content-type' => get_ctype(x[0])
      }
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "1968".murl},
      "issn" => Array(issn).map(&:iurl), "link" => links}
  when "1965"
    links = make_links(doi, json['urls'], json['components']['doi']['regex'])
    # url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "1965".murl}, "issn" => nil, "link" => links}
  when "301"
    links = make_links(doi, json['urls'], json['components']['doi']['regex'])
    # url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "301".murl}, "issn" => nil, "link" => links}
  when "194"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls']['pdf'] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => {"name" => memname, "url" => "194".murl},
      "issn" => Array(issn).map(&:iurl), "link" => url}
  when "4443"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls'][ctype] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => {"name" => memname, "url" => "4443".murl},
      "issn" => Array(issn).map(&:iurl), "link" => url}
  when "374"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    doi2 = doi.match(json['components']['doi']['regex']).to_s
    url = json['urls']['pdf'] % [
      doi2.split('-')[0],
      doi2.split('-')[1],
      res[0]['message']['volume'],
      'issue-' + res[0]['message']['issue'],
      doi2,
      doi2
    ]
    return {"doi" => doi, "member" => {"name" => memname, "url" => "374".murl},
      "issn" => Array(issn).map(&:iurl), "link" => url}
  when "221"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn.join('|')) }.any? }[0]

    if issn.include?("2375-2548")
      last_part = doi.match(bit['components']['doi']['regex']).to_s
    elsif issn.include?("1095-9203")
      last_part = res[0]['message']['page'].split('-')[0]
    end

    url = bit['urls']['pdf'] % [
      res[0]['message']['volume'],
      res[0]['message']['issue'],
      last_part
    ]
    return {"doi" => doi, "member" => {"name" => memname, "url" => "221".murl},
      "issn" => Array(issn).map(&:iurl), "link" => url}
  when "98"
    res = Serrano.works(ids: doi)

    begin
      url = res[0]['message']['link'].select { |x| x['content-type'].match(ctype) }[0]['URL']
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      url = json['urls']['pdf']
      if ctype == "xml"
        url = url.sub('pdf', 'xml')
      end
      doi_bit = doi.match(json['components']['doi']['regex']).to_s

      url = url % [res[0]['message'], doi_bit]
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "98".murl},
      "issn" => Array(issn).map(&:iurl), "link" => url}
  when "266"
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex'])[0]
    url = url % doi_bit
    return {"doi" => doi, "member" => {"name" => memname, "url" => "266".murl}, "issn" => nil, "link" => url}
  else
    return {"doi" => doi, "member" => nil, "issn" => nil, "link" => nil}
  end
end

def fetch_download
  acc = env["HTTP_ACCEPT"]
  if !['application/xml', 'application/pdf', 'xml', 'pdf'].include? acc
    acc = nil
  end

  browser_ua = !env["HTTP_USER_AGENT"].match(/Mozilla|AppleWebKit|Chrome|Safari/im).nil?

  z = [acc, params["type"]].compact

  # if browser user agent, go with whatever's available, prefer pdf first
  if browser_ua and params["type"].nil?
    z = ["pdf"]
  end

  if z.nil? or z.length != 1
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'either Accept header or "type" parameter should be passed on /doi and /api/fetch' })
  end

  z = z[0]

  if !['application/xml', 'application/pdf', 'xml', 'pdf'].include? z
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'Accept header must be one of "application/xml", "application/pdf"; type parameter must be one of: xml, pdf' })
  end

  case z
  when /pdf/
    z = 'application/pdf'
  else
    z = 'application/xml'
  end

  x = fetch_url
  urls = x["link"]
  # puts urls

  # if browser, go with whatever's available, prefer pdf first
  if browser_ua
    tmp = urls.select { |w| w['content-type'].match(z) }
    if tmp.length
      urltarget = tmp[0]['url']
    else
      if z == "application/pdf"
        z = 'application/xml'
      else
        z == "application/pdf"
      end
      tmp = urls.select { |w| w['content-type'].match(z) }
      urltarget = tmp[0]['url']
    end
  else
    # if not browser, error if not available
    tmp = urls.select { |w| w['content-type'].match(z) }
    urltarget = tmp[0]['url']
    if !urltarget.length
      halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'no url find for content type: ' + z })
    end
  end

  return urltarget
end
