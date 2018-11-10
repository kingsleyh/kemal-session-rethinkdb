require "json"
require "kemal-session"

module Kemal
  class Session
    class RethinkDBEngine < Engine
      class StorageInstance
        macro define_storage(vars)
              JSON.mapping({
                {% for name, type in vars %}
                  {{name.id}}s: Hash(String, {{type}}),
                {% end %}
              })

              {% for name, type in vars %}
                @{{name.id}}s = Hash(String, {{type}}).new
                getter {{name.id}}s

                def {{name.id}}(k : String) : {{type}}
                  return @{{name.id}}s[k]
                end

                def {{name.id}}?(k : String) : {{type}}?
                  return @{{name.id}}s[k]?
                end

                def {{name.id}}(k : String, v : {{type}})
                  @{{name.id}}s[k] = v
                end

                def delete_{{name.id}}(k : String)
                  if @{{name.id}}s[k]?
                    @{{name.id}}s.delete(k)
                  end
                end
              {% end %}

              def initialize
                {% for name, type in vars %}
                  @{{name.id}}s = Hash(String, {{type}}).new
                {% end %}
              end
        end

        define_storage({
          int:    Int32,
          bigint: Int64,
          string: String,
          float:  Float64,
          bool:   Bool,
          object: Session::StorableObject::StorableObjectContainer,
        })
      end

      @cache : Hash(String, StorageInstance)
      @cached_session_read_times : Hash(String, Time)

      def initialize(@connection : RethinkDB::Connection, @sessiontable : String = "sessions", @cachetime : Int32 = 5)
        # check if table exists, if not create it
        r.table_create(@sessiontable).run(@connection) unless r.table_list.run(@connection).includes?(@sessiontable)
        @cache = {} of String => StorageInstance
        @cached_session_read_times = {} of String => Time
      end

      def run_gc
        # delete old sessions here
        expiretime = Time.now - Kemal::Session.config.timeout
        r.table(@sessiontable).filter { |x| x["updated_at"].lt(expiretime) }.delete().run(@connection)
        # delete old memory cache too, if it exists and is too old
        @cache.each do |session_id, session|
          if @cached_session_read_times[session_id]? && (Time.utc_now.to_unix - @cachetime) > @cached_session_read_times[session_id].to_unix
            @cache.delete(session_id)
            @cached_session_read_times.delete(session_id)
          end
        end
      end

      def all_sessions : Array(StorageInstance)
        r.table(@sessiontable).run(@connection).to_a.map do |qr|
          StorageInstance.from_json(qr["data"].to_s)
        end
      end

      def create_session(session_id : String)
        session = StorageInstance.new
        data = session.to_json
        r.table(@sessiontable).insert({session_id: session_id, data: data, updated_at: r.now}, conflict: "replace").run(@connection)
        session
      end

      def save_cache(session_id)
        data = @cache[session_id].to_json
        r.table(@sessiontable).filter({session_id: session_id}).update({data: data, updated_at: r.now}).run(@connection)
      end

      def each_session
        r.table(@sessiontable).run(@connection).to_a.each do |qr|
          yield StorageInstance.from_json(qr["data"].to_s)
        end
      end

      def get_session(session_id : String)
        Session.new(session_id) if session_exists?(session_id)
      end

      def session_exists?(session_id : String) : Bool
        r.table(@sessiontable).filter({session_id: session_id}).run(@connection).to_a.size > 0
      end

      def destroy_session(session_id : String)
        r.table(@sessiontable).filter({session_id: session_id}).delete.run(@connection)
      end

      def destroy_all_sessions
        r.table(@sessiontable).delete.run(@connection)
      end

      def load_into_cache(session_id : String) : StorageInstance
        begin
          json = r.table(@sessiontable).filter({session_id: session_id}).run(@connection).to_a.first["data"].to_s
          @cache[session_id] = StorageInstance.from_json(json)
        rescue ex
          # recreates session based on id, if it has been deleted?
          @cache[session_id] = create_session(session_id)
        end
        @cached_session_read_times[session_id] = Time.utc_now
        r.table(@sessiontable).filter({session_id: session_id}).update({updated_at: r.now}).run(@connection)
        @cache[session_id]
      end

      def is_in_cache?(session_id : String) : Bool
        # only read from db once ever 'n' seconds. This should help with a single webpage hitting the db for every asset
        return false if !@cached_session_read_times[session_id]? # if not in cache reload it
        not_too_old = (Time.utc_now.to_unix - @cachetime) <= @cached_session_read_times[session_id].to_unix
        return not_too_old # if it is too old, load_into_cache will get called and it'll be reloaded
      end

      macro define_delegators(vars)
          {% for name, type in vars %}
            def {{name.id}}(session_id : String, k : String) : {{type}}
              load_into_cache(session_id) unless is_in_cache?(session_id)
              return @cache[session_id].{{name.id}}(k)
            end

            def {{name.id}}?(session_id : String, k : String) : {{type}}?
              load_into_cache(session_id) unless is_in_cache?(session_id)
              return @cache[session_id].{{name.id}}?(k)
            end

            def {{name.id}}(session_id : String, k : String, v : {{type}})
              load_into_cache(session_id) unless is_in_cache?(session_id)
              @cache[session_id].{{name.id}}(k, v)
              save_cache(session_id)
            end

            def {{name.id}}s(session_id : String) : Hash(String, {{type}})
              load_into_cache(session_id) unless is_in_cache?(session_id)
              return @cache[session_id].{{name.id}}s
            end
          {% end %}
        end

      define_delegators({
        int:    Int32,
        bigint: Int64,
        string: String,
        float:  Float64,
        bool:   Bool,
        object: Session::StorableObject::StorableObjectContainer,
      })
    end
  end
end
