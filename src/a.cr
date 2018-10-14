require "crystal-rethinkdb"
include RethinkDB::Shortcuts
c = r.connect(host: "localhost")

a = r.table("nice").run(c).to_a
p typeof(a)

# p r.table("omg").filter{|x| x["updated_at"].lt(Time.now)}.run(c).to_a
# p r.table("omg").run(c).to_a
# r.table_create("nice", primary_key: "session_id").run(c)
# p r.table("nice").delete().run(c)
