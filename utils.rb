require "multi_json"
require "serrano"
require "faraday"
require_relative "member_mapper"

# get mapper
def err_member(e)
  return { error: { message: "no mapper for the DOI" } }.to_json
end

def fetch_pattern_member
  path = $member_map[params["member"]]["path"]
  json = MultiJson.load(File.read(path))
  return json
end

def fetch_pattern_prefix
  path = $prefix_map[params["prefix"]]["path"]
  json = MultiJson.load(File.read(path))
  return json
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

# by doi
def fetch_url
  doi = params[:splat].first
  ctype = params['type'] || 'xml'

  x = Serrano.works(ids: doi)
  mem = x[0]['message']['member']
  mem_num = mem.split('/').last
  begin
    path = $member_map[mem_num]["path"]
  rescue Exception => e
    halt 404, err_member(e)
  end

  json = MultiJson.load(File.read(path))

  case mem_num
  when "4374"
    url = json['journals'][0]['urls'][ctype] % doi.match(json['journals'][0]['components']['doi']['regex'])
    return {"doi" => doi, "member" => "4374".murl, "issn" => "2050-084X".iurl, "url" => url}
  when "2258"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    url = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]['urls'][ctype] %
      doi.match(json['journals'][0]['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => "2258".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
  when "340"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls'][ctype] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => "340".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
  when "1968"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    url = json['urls']['xml'] % [issn, res[0]['message']['volume'], res[0]['message']['issue'], doi.match(json['components']['doi']['regex']).to_s.sub!(/^[0]+/, "") ]
    return {"doi" => doi, "member" => "1968".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
  when "1965"
    url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => "1965".murl, "issn" => nil, "url" => url}
  when "301"
    url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => "301".murl, "issn" => nil, "url" => url}
  when "194"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls']['pdf'] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => "194".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
  when "4443"
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls'][ctype] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => "4443".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
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
    return {"doi" => doi, "member" => "374".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
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
    return {"doi" => doi, "member" => "221".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
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

    return {"doi" => doi, "member" => "98".murl, "issn" => Array(issn).map(&:iurl), "url" => url}
  when "266"
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex'])[0]
    url = url % doi_bit
    return {"doi" => doi, "member" => "266".murl, "issn" => nil, "url" => url}
  else
    return {"doi" => doi, "member" => nil, "issn" => nil, "url" => nil}
  end
end
