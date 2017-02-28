Pubpatterns API
===============

see also: <https://github.com/ropenscilabs/pubpatterns>

Figuring out URLs for full text version of articles is a huge PITA.

There's <https://doi.org> for resolving DOIs to their full URLs on the web, and
there's <https://oadoi.org/> for the same but to OA versions.

However, there's no good tool for figuring out links to versions for text mining:
typically either pdf or xml.

There is Crossref's TDM (text and data mining) bit, where publishers voluntarily
deposit full text links into Crossref's metadata. However, very few publishers
do this; some that do don't deposit correct metadata; some deposit but don't update
when they change their URL structure (and publishers change URL stucture __A LOT__).

This API builds on work at <https://github.com/ropenscilabs/pubpatterns> - which
is simply rules for building URLs.

This API allows you to give a DOI and get back full text URLs for PDF/XML/etc. if
available.  And if they aren't available chip in and make it work.

## Under the hood

* API: Ruby/Sinatra
* Caching: None right, now, but will do Redis if used
* Server: Caddy
  * https
* Authentication: none

## setup

* static files in <https://github.com/ropenscilabs/pubpatterns/tree/master/src> define patterns
* we use these patterns to generate urls depending on the publisher, which can be determined from the DOI or given by the user
* patterns are simply read from disk from the `src/` dir - simple, no database

## API

* root path `/` - redirects to `/heartbeat/`
* `/heartbeat` - list routes
* `/members` - list all members with known patterns
* `/members/:member` - list a single member
* `/prefixes/:prefix` - some publishers are inside of bigger publishers & don't have own Crossref member number, but do have their own prefix
* `/doi` - get full text links and other metadata
* `/fetch` - redirect to the full text url

```r
{
    "routes": [
        "/heartbeat",
        "/members",
        "/members/:member",
        "/prefixes/:prefix",
        "/doi/*",
        "/fetch/*"
    ]
}
```

## Examples

### all members

```bash
curl -v 'http://127.0.0.1:8877/members' | jq .
```

### inividual crossref members

```bash
# eLife
curl -v 'http://127.0.0.1:8877/members/4374' | jq .

# Pensoft
curl -v 'http://127.0.0.1:8877/members/2258' | jq .

# PLOS
curl -v 'http://127.0.0.1:8877/members/340' | jq .

# DeGruyter
curl -v 'http://127.0.0.1:8877/members/374' | jq .

# Hindawi
curl -v 'http://127.0.0.1:8877/members/98' | jq .
```

### doi prefixes

Some publishers are inside of bigger publishers, so don't have their own Crossref member number, but do have their own DOI prefix, so we can use that to construct URLs for all their journals

```bash
# cogent
curl -v 'http://127.0.0.1:8877/prefixes/10.1080' | jq .
```

### full text links

API to get link information - gives doi, xml, and pdf links

```bash
# eLife
curl -v 'http://127.0.0.1:8877/doi/10.7554/eLife.07404' | jq .

# PeerJ
curl -v 'http://127.0.0.1:8877/doi/10.7717/peerj.991' | jq .

# Pensoft
curl -v 'http://127.0.0.1:8877/doi/10.3897/zookeys.594.8768' | jq .

# PLOS
curl -v 'http://127.0.0.1:8877/doi/10.1371/journal.pgen.1006546' | jq .

# MDPI
curl -v 'http://127.0.0.1:8877/doi/10.3390/a7010032' | jq .

# FrontersIn
curl -v 'http://127.0.0.1:8877/doi/10.3389/fmed.2015.00081' | jq .

# Thieme
curl -v 'http://127.0.0.1:8877/doi/10.1055/s-0042-103414' | jq .

# DeGruyter
curl -v 'http://127.0.0.1:8877/doi/10.1515/bj-2015-0021' | jq .
curl -v 'http://127.0.0.1:8877/doi/10.1515/jim-2016-0069' | jq .
curl -v 'http://127.0.0.1:8877/doi/10.1515/contagri-2016-0010' | jq .

# AAAS
## Science Advances
curl -v 'http://127.0.0.1:8877/doi/10.1126/sciadv.1602209' | jq .

## Science
curl -v 'http://127.0.0.1:8877/doi/10.1126/science.aag2360' | jq .

## Hindawi
curl -v 'http://127.0.0.1:8877/doi/10.1155/2013/520285' | jq .
```
