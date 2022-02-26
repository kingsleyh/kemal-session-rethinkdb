# kemal-session-rethinkdb

This is a [RethinkDB](http://rethinkdb.com/) adaptor for [Kemal Session](https://github.com/kemalcr/kemal-session)

[![Build Status](https://travis-ci.org/kingsleyh/kemal-session-rethinkdb.svg?branch=master)](https://travis-ci.org/kingsleyh/kemal-session-rethinkdb) [![Crystal Version](https://img.shields.io/badge/crystal%20-1.3.2-brightgreen.svg)](https://crystal-lang.org/api/1.3.2/)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  kemal-session-rethinkdb:
    github: kingsleyh/kemal-session-rethinkdb
  rethinkdb:
    github: kingsleyh/crystal-rethinkdb  
```

## Usage

```crystal
require "kemal"
require "kemal-session-rethinkdb"
require "rethinkdb"

include RethinkDB::Shortcuts

# connect to RethinkDB
connection = r.connect(host: "localhost")

Session.config do |config|
  config.cookie_name = "rethinkdb_test"
  config.secret = "a_secret"
  config.engine = Session::RethinkDBEngine.new(connection)
  config.timeout = 1.week
end

get "/" do
  puts "Hello World"
end

post "/sign_in" do |context|
  context.session.int("see-it-works", 1)
end

Kemal.run
```

If you are already using crystal-rethinkdb you can re-use the reference to your connection.

## Optional Parameters

```
Session.config do |config|
  config.cookie_name = "rethinkdb_test"
  config.secret = "a_secret"
  config.engine = Session::RethinkDBEngine.new(
    connection: connection,
    sessiontable: "sessions",
    cachetime: 5
  )
  config.timeout = Time::Span.new(1, 0, 0)
end
```

|Param        |Description
|----         |----
|connection   | A Crystal Mysql DB Connection
|sessiontable | Name of the table to use for sessions - defaults to "sessions"
|cachetime    | Number of seconds to hold the session data in memory, before re-reading from the database. This is set to 5 seconds by default, set to 0 to hit the db for every request.

## Bugs

Please raise any bugs as issues on github: [Issues](https://github.com/kingsleyh/kemal-session-rethinkdb/issues)

## Contributing

1. Fork it (<https://github.com/kingsleyh/kemal-session-rethinkdb/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [kingsleyh](https://github.com/kingsleyh) Kingsley Hendrickse - creator, maintainer
