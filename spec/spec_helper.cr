require "spec"
require "crystal-rethinkdb"
require "../src/kemal-session-rethinkdb"

include RethinkDB::Shortcuts

Conn = r.connect(host: "localhost")

SESSION_ID = Random::Secure.hex

Spec.before_each do
  Kemal::Session.config.secret = "super-awesome-secret"
  Kemal::Session.config.engine = Kemal::Session::RethinkDBEngine.new(Conn)
end

Spec.after_each do
  r.table_drop("sessions").run(Conn) if r.table_list.run(Conn).includes?("sessions")
end

def get_from_db(session_id : String)
  r.table("sessions").filter({session_id: session_id}).run(Conn).to_a.first["data"].to_s
end

def create_context(session_id : String)
  response = HTTP::Server::Response.new(IO::Memory.new)
  headers = HTTP::Headers.new

  unless session_id == ""
    Kemal::Session.config.engine.create_session(session_id)
    cookies = HTTP::Cookies.new
    cookies << HTTP::Cookie.new(Kemal::Session.config.cookie_name, Kemal::Session.encode(session_id))
    cookies.add_request_headers(headers)
  end

  request = HTTP::Request.new("GET", "/", headers)
  return HTTP::Server::Context.new(request, response)
end
class UserJsonSerializer
  JSON.mapping({
    id:   Int32,
    name: String,
  })
  include Kemal::Session::StorableObject

  def initialize(@id : Int32, @name : String); end

  def serialize
    self.to_json
  end

  def self.unserialize(value : String)
    UserJsonSerializer.from_json(value)
  end
end
