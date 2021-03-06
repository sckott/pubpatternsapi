require "multi_json"
require "serrano"
require "faraday"
require "oga"
require_relative "member_mapper"
require_relative "prefix_mapper"

# get mapper
def err_member(e)
  return { error: "no mapper for the DOI" }.to_json
end

# members
def fetch_pattern_member
  mem = $member_map[params["member"]]
  if mem.nil?
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'that member not supported yet' })
  end
  path = mem["path"]
  json = MultiJson.load(File.read(path))
  return json
end

def fetch_members
  out = $member_map.collect { |x| MultiJson.load(File.read(x[1]["path"])) }
  return out
end


# prefixes
def fetch_pattern_prefix
  pre = $prefix_map[params["prefix"]]
  if pre.nil?
    halt 400, {'Content-Type' => 'application/json'}, MultiJson.dump({ 'error' => 'that prefix not supported' })
  end
  path = pre["path"]
  json = MultiJson.load(File.read(path))
  return json
end

def fetch_prefixes
  out = $prefix_map.collect { |x| MultiJson.load(File.read(x[1]["path"])) }
  return out
end



class String
  def murl
    "https://api.crossref.org/members/" + self
  end
end

class String
  def iurl
    "https://api.crossref.org/journals/" + self
  end
end

def get_ctype(x)
  case x
  when 'pdf'
    ct = 'application/pdf'
  when 'xml'
    ct = 'application/xml'
  when 'html'
    ct = 'text/html'
  end
  return ct
end

def from_ctype(x)
  case x
  when 'pdf'
    ct = 'application/pdf'
  when 'xml'
    ct = 'application/xml'
  when 'html'
    ct = 'text/html'
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
  puts params['doi']
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
    halt 400, err_member(e)
  end

  json = MultiJson.load(File.read(path))

  case mem_num
  when "4374"
    # eLife
    links = make_links(doi, json['journals'][0]['urls'],
      json['journals'][0]['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "4374".murl},
      "issn" => "2050-084X".iurl, "links" => links}
  when "2258"
    # Pensoft Publishers
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    links = make_links(doi,
      json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]['urls'],
      json['journals'][0]['components']['doi']['regex']
    )
    return {"doi" => doi, "member" => {"name" => memname, "url" => "2258".murl},
      "issn" => Array(issn).map(&:iurl), "links" => links}
  when "340"
    # Public Library of Science (PLoS)
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    links = make_links(doi, bit['urls'], bit['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "340".murl},
      "issn" => Array(issn).map(&:iurl), "links" => links}
  when "1968"
    # MDPI AG
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
      "issn" => Array(issn).map(&:iurl), "links" => links}
  when "1965"
    # Frontiers
    links = make_links(doi, json['urls'], json['components']['doi']['regex'])
    # url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "1965".murl}, "issn" => nil, "links" => links}
  when "301"
    # Informa UK Limited
    links = make_links(doi, json['urls'], json['components']['doi']['regex'])
    # url = json['urls'][ctype] % doi.match(json['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "301".murl}, "issn" => nil, "links" => links}
  when "194"
    # Georg Thieme Verlag KG
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    url = bit['urls']['pdf'] % doi.match(bit['components']['doi']['regex']).to_s
    return {"doi" => doi, "member" => {"name" => memname, "url" => "194".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "4443"
    # PeerJ
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn) }.any? }[0]
    urls = make_links(doi, bit['urls'], bit['components']['doi']['regex'])
    return {"doi" => doi, "member" => {"name" => memname, "url" => "4443".murl},
      "issn" => Array(issn).map(&:iurl), "links" => urls}
  when "374"
    # Walter de Gruyter GmbH
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN'][0]
    urls = res[0]['message']['link'].map { |x| x['URL'] }

    types = []
    urls.each do |x|
      if x.match(/xml/).nil?
        types << "pdf"
      else
        types << "xml"
      end
    end
    out = Hash[types.zip(urls)] 

    return {"doi" => doi, "member" => {"name" => memname, "url" => "374".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out}
  when "221"
    # AAAS
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
      "issn" => Array(issn).map(&:iurl), "links" => { "pdf" => url } }
  when "98"
    # Hindawi
    res = Serrano.works(ids: doi)
    ctype = params["type"]

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
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "266"
    # IOP Publishing
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex'])[0]
    url = url % doi_bit
    return {"doi" => doi, "member" => {"name" => memname, "url" => "266".murl}, "issn" => nil, "links" => url}
  when "78"
    # Elsevier
    res = Serrano.works(ids: doi)
    ctype = params["type"]

    begin
      if ctype.nil?
        links = res[0]['message']['link'].map { |x| x['URL'] }
      else
        links = res[0]['message']['link'].select { |x| x['content-type'].match(ctype) }[0]['URL']
      end
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      links = json['urls']
      if res[0]['message']["alternative-id"].nil?
        links = nil
      else
        links = links.each { |x,y| links[x] = y % res[0]['message']["alternative-id"][0] }
        if !ctype.nil?
          links = links[ctype]
        end
      end
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "78".murl},
      "issn" => Array(issn).map(&:iurl), "links" => links}
  when "2899"
    # Association of Fire Ecology
    conn = Faraday.new(:url => "https://doi.org/" + doi) do |f|
      f.use FaradayMiddleware::FollowRedirects
      f.adapter  Faraday.default_adapter
    end
    out = conn.get
    out.body
    "citation_pdf_url"

    # fireecologyjournal.org/docs/Journal/pdf/Volume12/Issue01/124.pdf
    "http://" + pdf_url
  when "16"
    # American Phyiscal Society
    res = Serrano.works(ids: doi)
    # no need to do content type b/c only avail. is PDF

    begin
      url = res[0]['message']['link'].select { |x| x['intended-application'] == "similarity-checking" }[0]['URL']
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      url = json['urls']['pdf']
      doi_bit = doi.match(json['components']['doi']['regex']).to_s
      url = url % [res[0]['message'], doi_bit]
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "16".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "292"
    # Royal Society of Chemistry
    res = Serrano.works(ids: doi)
    # no need to do content type b/c only avail. is PDF

    begin
      url = res[0]['message']['link'].select { |x| x['intended-application'] == "similarity-checking" }[0]['URL']
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      url = json['urls']['pdf']
      doi_bit = doi.match(json['components']['doi']['regex']).to_s
      url = url % [res[0]['message'], doi_bit]
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "292".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "127"
    # Karger
    res = Serrano.works(ids: doi)
    # no need to do content type b/c only avail. is PDF

    begin
      url = res[0]['message']['link'].select { |x| x['intended-application'] == "similarity-checking" }[0]['URL']
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      url = json['urls']['pdf']
      doi_bit = doi.match(json['components']['doi']['regex']).to_s
      url = url % doi_bit
      issn = res[0]['message']['ISSN']
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "127".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "2457"
    # Trans Tech Publications
    res = Serrano.works(ids: doi)
    # no need to do content type b/c only avail. is PDF

    begin
      url = res[0]['message']['link'].select { |x| x['intended-application'] == "similarity-checking" }[0]['URL']
      issn = res[0]['message']['ISSN']
    rescue Exception => e
      url = json['urls']['pdf']
      doi_bit = doi.match(json['components']['doi']['regex']).to_s
      url = url % doi_bit
      issn = res[0]['message']['ISSN']
    end

    return {"doi" => doi, "member" => {"name" => memname, "url" => "2457".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "140"
    # Emerald
    res = Serrano.works(ids: doi)
    ctype = params["type"] || "pdf"

    issn = res[0]['message']['ISSN']
    doi_bit = doi.match(json['components']['doi']['regex']).to_s
    if ctype == "pdf"
      url = json['urls']['pdf']
    else
      url = json['urls']['html']
    end
    url = url % doi_bit
    return {"doi" => doi, "member" => {"name" => memname, "url" => "140".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "137"
    # Pleiades
    res = Serrano.works(ids: doi)
    # pdfs only, no type needed
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex']).to_s
    url = url % doi_bit
    return {"doi" => doi, "member" => {"name" => memname, "url" => "137".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "8215"
    # instituto_de_investigaciones_filologicas
    res = Serrano.works(ids: doi)
    # pdfs only, no type needed
    issn = res[0]['message']['ISSN']
    url = res[0]['message']['link'][0]['URL']
    url = url.sub('view', 'download')
    return {"doi" => doi, "member" => {"name" => memname, "url" => "8215".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "179"
    # Sage
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = res[0]['message']['link'][0]['URL']
    url = url.sub('view', 'download')
    return {"doi" => doi, "member" => {"name" => memname, "url" => "179".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url}
  when "189"
    # SPIE
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex']).to_s
    url = url % doi_bit

    return { "doi" => doi, "member" => {"name" => memname, "url" => "189".murl},
      "issn" => Array(issn).map(&:iurl), "links" => url, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "341"
    # PNAS
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf']

    url = url % [ res[0]['message']['volume'], res[0]['message']['issue'], 
      res[0]['message']['page'].split('-')[0].sub('E', '') ]
    return { "doi" => doi, "member" => {"name" => memname, "url" => "341".murl},
      "issn" => Array(issn).map(&:iurl), "links" => { "pdf" => url }, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "297"
    # Springer
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf']
    doi_bit = doi.match(json['components']['doi']['regex']).to_s
    url = url % doi_bit

    return { "doi" => doi, "member" => {"name" => memname, "url" => "297".murl},
      "issn" => Array(issn).map(&:iurl), "links" => { "pdf" => url }, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "345"
    # Microbiology Society
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn.join('|')) }.any? }[0]
    
    # just scrape site
    conn = Faraday.new(:url => "https://doi.org/" + doi) do |f|
      f.use FaradayMiddleware::FollowRedirects
      f.adapter  Faraday.default_adapter
    end
    out = conn.get;
    html = Oga.parse_html(out.body);
    pdfnode = html.xpath('//a[contains(@class, "externallink pdf")]')[0]
    ending = pdfnode.attr('href').text.sub(/\?.+/, '')
    pdf_url = "http://%s.microbiologyresearch.org%s" % [bit['journal'], ending]
    
    out = []
    out << {
      'url' => pdf_url,
      'content-type' => get_ctype('pdf')
    }

    htmlref = doi.match(bit['components']['html']['regex']).to_s
    out << {
      'url' => bit['urls']['html'] % htmlref,
      'content-type' => get_ctype('html')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "345".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "10" # JAMA
    res = Serrano.works(ids: doi);
    issn = res[0]['message']['ISSN']

    # doi = "10.1001/jamaoncol.2017.4000" # good
    # doi = "10.1001/jama.2014.4318" # bad
    conn = Faraday.new(:url => "https://doi.org/" + doi) do |f|
      f.use FaradayMiddleware::FollowRedirects, {limit: 6}
      f.adapter  Faraday.default_adapter
    end
    begin
      out = conn.get;
    rescue Exception => e
      halt 500, { error: "failed attempting to scrape the landing page" }.to_json
    end
    html = Oga.parse_html(out.body);
    pdf_url = html.xpath('//meta[@name="citation_pdf_url"]')[0].attr('content').text
    html_url = pdf_url.sub('articlepdf', 'fullarticle')[/.*\//]

    out = []
    out << {
      'url' => pdf_url,
      'content-type' => get_ctype('pdf')
    }
    out << {
      'url' => html_url,
      'content-type' => get_ctype('html')
    }

    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "10".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "235" # American Society for Microbiology
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf']
    vol = res[0]['message']['volume']
    iss = res[0]['message']['issue']
    journal_bit = doi.match('[A-Za-z]+').to_s.downcase
    other_bit = doi.split('/')[1].match('[0-9]+-[0-9]+').to_s
    pdf_url = url % [journal_bit, vol, iss, other_bit] 
    out = []
    out << {
      'url' => pdf_url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "235".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "233" # American Society of Clinical Oncology
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf'] % doi
    out = []
    out << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "233".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "317" # AIP
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    url = json['urls']['pdf'] % doi
    out = []
    out << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "317".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "316" # ACS
    res = Serrano.works(ids: doi)
    issn = res[0]['message']['ISSN']
    if res[0]['message']['link'].nil?
      urls = ["https://pubs.acs.org/doi/pdf/%s" % doi]
    else
      urls = res[0]['message']['link'].map { |x| x['URL'] }
    end
    out = []
    out << {
      'url' => urls[0],
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "316".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "175" # The Royal Society
    res = Serrano.works(ids: doi, verbose: true)
    issn = res[0]['message']['ISSN'][0]
    url = json['urls']['pdf'] % doi
    out = []
    out << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
      "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "175".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "237" # Company of Biologists
    res = Serrano.works(ids: doi);
    issn = res[0]['message']['ISSN']
    bit = json['journals'].select { |x| Array(x['issn']).select{ |z| !!z.match(issn.first) }.any? }[0]

    pp = res[0]['message']['page']
    # if pp.match(/-/)
    #   page_part = pp.split('-')[0].match("[0-9]+$").to_s
    # else
    #   page_part = res[0]['message']['page'].match("[0-9]+$").to_s
    # end

    url = bit["urls"]["pdf"] % [ res[0]['message']['volume'], res[0]['message']['issue'], pp ]
    out = []
    out << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "member" => {"name" => memname, "url" => "237".murl},
      "issn" => Array(issn).map(&:iurl), "links" => out, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "246" # Biorxiv
    res = Serrano.works(ids: doi);
    conn = Faraday.new(:url => "https://doi.org/" + doi) do |f|
      f.use FaradayMiddleware::FollowRedirects
      f.adapter  Faraday.default_adapter
    end
    out = conn.get;
    html = Oga.parse_html(out.body);
    pdfurl = html.xpath('//meta[@name="citation_pdf_url"]')[0].attr('content').text
    pdf_url = []
    pdf_url << {
      'url' => pdfurl,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "member" => {"name" => memname, "url" => "246".murl},
      "issn" => nil, "links" => pdf_url, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "286" # Oxford
    res = Serrano.works(ids: doi);
    issn = res[0]['message']['ISSN']
    url = res[0]['message']['link'][0]['URL']
    if url.match(/article-pdf/).nil?
      url = nil
    end
    pdf_url = []
    pdf_url << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "member" => {"name" => memname, "url" => "286".murl},
      "issn" => Array(issn).map(&:iurl), "links" => pdf_url, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  when "1822" # CDC
    res = Serrano.works(ids: doi);
    issn = res[0]['message']['ISSN']
    year = res[0]['message']['created']['date-parts'][0][0]
    pdf_url = []
    doi_part = doi.split('/').last.split('.').last
    url = json['urls']['pdf'] % [year.to_s, [doi_part[0..1], doi_part[2..]].join('_')]
    pdf_url << {
      'url' => url,
      'content-type' => get_ctype('pdf')
    }
    return { "doi" => doi, "member" => {"name" => memname, "url" => "1822".murl},
      "issn" => Array(issn).map(&:iurl), "links" => pdf_url, 
      "cookies" => json['cookies'], "open_access" => json['open_access']  }
  # when "56" # Cambridge
  #   res = Serrano.works(ids: doi, verbose: true)
  #   issn = res[0]['message']['ISSN'][0]
  #   conn = Faraday.new(:url => "https://doi.org/" + doi) do |f|
  #     f.use FaradayMiddleware::FollowRedirects
  #     f.adapter  Faraday.default_adapter
  #   end
  #   out = conn.get;
  #   html = Oga.parse_html(out.body);
  #   pdf_url = "https://www.cambridge.org" + html.xpath('//a[@aria-label="Download PDF"]')[0].attr('href').text

  #   out = []
  #   out << {
  #     'url' => pdf_url,
  #     'content-type' => get_ctype('pdf')
  #   }
  #   return { "doi" => doi, "title" => res[0]['message']['container-title'][0].strip, 
  #     "member" => {"name" => memname, "publisher" => res[0]['message']['publisher'], "url" => "56".murl},
  #     "issn" => Array(issn).map(&:iurl), "links" => out, 
  #     "cookies" => json['cookies'], "open_access" => json['open_access']  }
  else
    return {"doi" => doi, "member" => nil, "issn" => nil, "links" => nil}
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
  urls = x["links"]
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
