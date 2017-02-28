Pubpatterns API
===============

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
* Storage: MySQL
* Search: ...
* Caching: Redis
  * each key cached for 3 hours
* Server: Caddy
  * https
* Authentication: none

## setup

* static files in `ropenscilabs/pubpatterns/src` define patterns
* we use these patterns to generate urls depending on the publisher, which can be determined from the DOI or given by the user
* patterns are simply read from disk from the `src/` dir - simple, no database
*

## API

* root path <http://xxxx> - redirects to `/heartbeat`
* `/heartbeat`

```r
{
    "routes": [
        "/heartbeat",
        "/patterns/member/:member",
        "/patterns/prefix/:member",
        "/doi/*",
        "/fetch/*"
    ]
}
```

* `/xxx` - list datasets and minimal metadata
* `/xxx/:xxx` - dataset metadata

## Examples

### patterns 

#### crossref member numbers

```bash
# eLife
curl -v 'http://127.0.0.1:8877/patterns/member/4374' | jq .

# Pensoft
curl -v 'http://127.0.0.1:8877/patterns/member/2258' | jq .

# PLOS
curl -v 'http://127.0.0.1:8877/patterns/member/340' | jq .

# DeGruyter
curl -v 'http://127.0.0.1:8877/patterns/member/374' | jq .

# Hindawi
curl -v 'http://127.0.0.1:8877/patterns/member/98' | jq .
```

#### doi prefixes 

Some publishers are inside of bigger publishers, so don't have their own Crossref member number, but do have their own DOI prefix, so we can use that to construct URLs for all their journals

```bash
# cogent
curl -v 'http://127.0.0.1:8877/patterns/prefix/10.1080' | jq .
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
