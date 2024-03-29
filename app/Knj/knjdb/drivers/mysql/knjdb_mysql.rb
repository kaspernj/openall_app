class KnjDB_mysql
  attr_reader :knjdb, :conn, :conns, :escape_table, :escape_col, :escape_val, :esc_table
  attr_accessor :tables, :cols, :indexes
  
  def initialize(knjdb_ob)
    @knjdb = knjdb_ob
    @opts = @knjdb.opts
    @escape_table = "`"
    @escape_col = "`"
    @escape_val = "'"
    @esc_table = "`"
    @esc_col = "`"
    @mutex = Mutex.new
    
    if @opts[:encoding]
      @encoding = @opts[:encoding]
    else
      @encoding = "utf8"
    end
    
    if @knjdb.opts.key?(:port)
      @port = @knjdb.opts[:port].to_i
    else
      @port = 3306
    end
    
    @java_rs_data = {}
    @subtype = @knjdb.opts[:subtype]
    @subtype = "mysql" if @subtype.to_s.length <= 0
    self.reconnect
  end
  
  #This method handels the closing of statements and results for the Java MySQL-mode.
  def java_mysql_resultset_killer(id)
    data = @java_rs_data[id]
    return nil if !data
    
    data[:res].close
    data[:stmt].close
    @java_rs_data.delete(id)
  end
  
  #Cleans the wref-map holding the tables.
  def clean
    self.tables.clean if self.tables
  end
  
  #Respawns the connection to the MySQL-database.
  def reconnect
    case @subtype
      when "mysql"
        @conn = Mysql.real_connect(@knjdb.opts[:host], @knjdb.opts[:user], @knjdb.opts[:pass], @knjdb.opts[:db], @port)
      when "mysql2"
        require "rubygems"
        require "mysql2"
        
        args = {
          :host => @knjdb.opts[:host],
          :username => @knjdb.opts[:user],
          :password => @knjdb.opts[:pass],
          :database => @knjdb.opts[:db],
          :port => @port,
          :symbolize_keys => true,
          :cache_rows => false
        }
        
        #Symbolize keys should also be given here, else table-data wont be symbolized for some reason - knj.
        @query_args = {:symbolize_keys => true}
        @query_args.merge!(@knjdb.opts[:query_args]) if @knjdb.opts[:query_args]
        
        pos_args = [:as, :async, :cast_booleans, :database_timezone, :application_timezone, :cache_rows, :connect_flags, :cast]
        pos_args.each do |key|
          args[key] = @knjdb.opts[key] if @knjdb.opts.key?(key)
        end
        
        args[:as] = :array if @opts[:result] == "array"
        
        tries = 0
        begin
          tries += 1
          @conn = Mysql2::Client.new(args)
        rescue => e
          if tries <= 3
            if e.message == "Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock' (111)"
              sleep 1
              retry
            end
          end
          
          raise e
        end
      when "java"
        if !@jdbc_loaded
          require "java"
          require "/usr/share/java/mysql-connector-java.jar" if File.exists?("/usr/share/java/mysql-connector-java.jar")
          import "com.mysql.jdbc.Driver"
          @jdbc_loaded = true
        end
        
        @conn = java.sql::DriverManager.getConnection("jdbc:mysql://#{@knjdb.opts[:host]}:#{@port}/#{@knjdb.opts[:db]}?user=#{@knjdb.opts[:user]}&password=#{@knjdb.opts[:pass]}&populateInsertRowWithDefaultValues=true&zeroDateTimeBehavior=round&characterEncoding=#{@encoding}&holdResultsOpenOverStatementClose=true")
        self.query("SET SQL_MODE = ''")
      else
        raise "Unknown subtype: #{@subtype}"
    end
    
    self.query("SET NAMES '#{self.esc(@encoding)}'") if @encoding
  end
  
  #Executes a query and returns the result.
  def query(str)
    str = str.to_s
    str = str.force_encoding("UTF-8") if @encoding == "utf8" and str.respond_to?(:force_encoding)
    tries = 0
    
    begin
      tries += 1
      @mutex.synchronize do
        case @subtype
          when "mysql"
            return KnjDB_mysql_result.new(self, @conn.query(str))
          when "mysql2"
            return KnjDB_mysql2_result.new(@conn.query(str, @query_args))
          when "java"
            stmt = conn.create_statement
            
            if str.match(/^\s*(delete|update|create|drop|insert\s+into|alter)\s+/i)
              begin
                stmt.execute(str)
              ensure
                stmt.close
              end
              
              return nil
            else
              id = nil
              
              begin
                res = stmt.execute_query(str)
                ret = KnjDB_java_mysql_result.new(@knjdb, @opts, res)
                id = ret.__id__
                
                #If ID is being reused we have to free the result.
                self.java_mysql_resultset_killer(id) if @java_rs_data.key?(id)
                
                #Save reference to result and statement, so we can close them when they are garbage collected.
                @java_rs_data[id] = {:res => res, :stmt => stmt}
                ObjectSpace.define_finalizer(ret, self.method("java_mysql_resultset_killer"))
                
                return ret
              rescue => e
                res.close if res
                stmt.close
                @java_rs_data.delete(id) if ret and id
                raise e
              end
            end
          else
            raise "Unknown subtype: '#{@subtype}'."
        end
      end
    rescue => e
      if tries < 3
        if e.message == "MySQL server has gone away" or e.message == "closed MySQL connection" or e.message == "Can't connect to local MySQL server through socket"
          sleep 0.5
          self.reconnect
          retry
        elsif e.to_s.index("No operations allowed after connection closed") != nil or e.message == "This connection is still waiting for a result, try again once you have the result"
          self.reconnect
          retry
        end
      end
      
      #print str
      raise e
    end
  end
  
  #Executes an unbuffered query and returns the result that can be used to access the data.
  def query_ubuf(str)
    @mutex.synchronize do
      case @subtype
        when "mysql"
          @conn.query_with_result = false
          return KnjDB_mysql_unbuffered_result.new(@conn, @opts, @conn.query(str))
        when "mysql2"
          return KnjDB_mysql2_result.new(@conn.query(str, @query_args.merge(:stream => true)))
        when "java"
          if str.match(/^\s*(delete|update|create|drop|insert\s+into)\s+/i)
            stmt = @conn.createStatement
            
            begin
              stmt.execute(str)
            ensure
              stmt.close
            end
            
            return nil
          else
            stmt = @conn.createStatement(java.sql.ResultSet.TYPE_FORWARD_ONLY, java.sql.ResultSet.CONCUR_READ_ONLY)
            stmt.setFetchSize(java.lang.Integer::MIN_VALUE)
            
            begin
              res = stmt.executeQuery(str)
              ret = KnjDB_java_mysql_result.new(@knjdb, @opts, res)
              
              #Save reference to result and statement, so we can close them when they are garbage collected.
              @java_rs_data[ret.__id__] = {:res => res, :stmt => stmt}
              ObjectSpace.define_finalizer(ret, self.method("java_mysql_resultset_killer"))
              
              return ret
            rescue => e
              res.close if res
              stmt.close
              raise e
            end
          end
        else
          raise "Unknown subtype: '#{@subtype}'"
      end
    end
  end
  
  #Escapes a string to be safe to use in a query.
  def escape_alternative(string)
    case @subtype
      when "mysql"
        return @conn.escape_string(string.to_s)
      when "mysql2"
        return @conn.escape(string.to_s)
      when "java"
        return self.escape(string)
      else
        raise "Unknown subtype: '#{@subtype}'."
    end
  end
  
  #An alternative to the MySQL framework's escape. This is copied from the Ruby/MySQL framework at: http://www.tmtm.org/en/ruby/mysql/
  def escape(string)
    return string.to_s.gsub(/([\0\n\r\032\'\"\\])/) do
      case $1
        when "\0" then "\\0"
        when "\n" then "\\n"
        when "\r" then "\\r"
        when "\032" then "\\Z"
        else "\\#{$1}"
      end
    end
  end
  
  #Escapes a string to be safe to use as a column in a query.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.index(@escape_col) != nil
    return string
  end
  
  alias :esc_table :esc_col
  alias :esc :escape
  
  #Returns the last inserted ID for the connection.
  def lastID
    case @subtype
      when "mysql"
        @mutex.synchronize do
          return @conn.insert_id.to_i
        end
      when "mysql2"
        @mutex.synchronize do
          return @conn.last_id.to_i
        end
      when "java"
        data = self.query("SELECT LAST_INSERT_ID() AS id").fetch
        return data[:id].to_i if data.key?(:id)
        raise "Could not figure out last inserted ID."
    end
  end
  
  #Closes the connection threadsafe.
  def close
    @mutex.synchronize do
      @conn.close
    end
  end
  
  #Destroyes the connection.
  def destroy
    @conn = nil
    @knjdb = nil
    @mutex = nil
    @subtype = nil
    @encoding = nil
    @query_args = nil
    @port = nil
  end
  
  #Inserts multiple rows in a table. Can return the inserted IDs if asked to in arguments.
  def insert_multi(tablename, arr_hashes, args = nil)
    sql = "INSERT INTO `#{tablename}` ("
    
    first = true
    if args and args[:keys]
      keys = args[:keys]
    elsif arr_hashes.first.is_a?(Hash)
      keys = arr_hashes.first.keys
    else
      raise "Could not figure out keys."
    end
    
    keys.each do |col_name|
      sql << "," if !first
      first = false if first
      sql << "`#{self.esc_col(col_name)}`"
    end
    
    sql << ") VALUES ("
    
    first = true
    arr_hashes.each do |hash|
      if first
        first = false
      else
        sql << "),("
      end
      
      first_key = true
      if hash.is_a?(Array)
        hash.each do |val|
          if first_key
            first_key = false
          else
            sql << ","
          end
          
          sql << "'#{self.escape(val)}'"
        end
      else
        hash.each do |key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end
          
          sql << "'#{self.escape(val)}'"
        end
      end
    end
    
    sql << ")"
    
    return sql if args and args[:return_sql]
    
    self.query(sql)
    
    if args and args[:return_id]
      first_id = self.lastID
      raise "Invalid ID: #{first_id}" if first_id.to_i <= 0
      ids = [first_id]
      1.upto(arr_hashes.length - 1) do |count|
        ids << first_id + count
      end
      
      ids_length = ids.length
      arr_hashes_length = arr_hashes.length
      raise "Invalid length (#{ids_length}, #{arr_hashes_length})." if ids_length != arr_hashes_length
      
      return ids
    else
      return nil
    end
  end
  
  #Starts a transaction, yields the database and commits at the end.
  def transaction
    @knjdb.q("START TRANSACTION")
    
    begin
      yield(@knjdb)
    ensure
      @knjdb.q("COMMIT")
    end
  end
end

#This class controls the results for the normal MySQL-driver.
class KnjDB_mysql_result
  #Constructor. This should not be called manually.
  def initialize(driver, result)
    @driver = driver
    @result = result
    @mutex = Mutex.new
    
    if @result
      @keys = []
      keys = @result.fetch_fields
      keys.each do |key|
        @keys << key.name.to_sym
      end
    end
  end
  
  #Returns a single result.
  def fetch
    return self.fetch_hash_symbols if @driver.knjdb.opts[:return_keys] == "symbols"
    return self.fetch_hash_strings
  end
  
  #Returns a single result as a hash with strings as keys.
  def fetch_hash_strings
    @mutex.synchronize do
      return @result.fetch_hash
    end
  end
  
  #Returns a single result as a hash with symbols as keys.
  def fetch_hash_symbols
    fetched = nil
    @mutex.synchronize do
      fetched = @result.fetch_row
    end
    
    return false if !fetched
    
    ret = {}
    count = 0
    @keys.each do |key|
      ret[key] = fetched[count]
      count += 1
    end
    
    return ret
  end
  
  #Loops over every result yielding it.
  def each
    while data = self.fetch_hash_symbols
      yield(data)
    end
  end
end

#This class controls the unbuffered result for the normal MySQL-driver.
class KnjDB_mysql_unbuffered_result
  #Constructor. This should not be called manually.
  def initialize(conn, opts, result)
    @conn = conn
    @result = result
    
    if !opts.key?(:result) or opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end
  
  #Lods the keys for the object.
  def load_keys
    @keys = []
    keys = @res.fetch_fields
    keys.each do |key|
      @keys << key.name.to_sym
    end
  end
  
  #Returns a single result.
  def fetch
    if @enum
      begin
        ret = @enum.next
      rescue StopIteration
        @enum = nil
        @res = nil
      end
    end
    
    if !ret and !@res and !@enum
      begin
        @res = @conn.use_result
        @enum = @res.to_enum
        ret = @enum.next
      rescue Mysql::Error
        #Reset it to run non-unbuffered again and then return false.
        @conn.query_with_result = true
        return false
      rescue StopIteration
        sleep 0.1
        retry
      end
    end
    
    if !@as_hash
      return ret
    else
      self.load_keys if !@keys
      
      ret_h = {}
      @keys.each_index do |key_no|
        ret_h[@keys[key_no]] = ret[key_no]
      end
      
      return ret_h
    end
  end
  
  #Loops over every single result yielding it.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end

#This class controls the result for the MySQL2 driver.
class KnjDB_mysql2_result
  #Constructor. This should not be called manually.
  def initialize(result)
    @result = result
  end
  
  #Returns a single result.
  def fetch
    @enum = @result.to_enum if !@enum
    
    begin
      return @enum.next
    rescue StopIteration
      return false
    end
  end
  
  #Loops over every single result yielding it.
  def each
    @result.each do |res|
      #This sometimes happens when streaming results...
      next if !res
      yield(res)
    end
  end
end

#This class controls the result for the Java-MySQL-driver.
class KnjDB_java_mysql_result
  #Constructor. This should not be called manually.
  def initialize(knjdb, opts, result)
    @knjdb = knjdb
    @result = result
    
    if !opts.key?(:result) or opts[:result] == "hash"
      @as_hash = true
    elsif opts[:result] == "array"
      @as_hash = false
    else
      raise "Unknown type of result: '#{opts[:result]}'."
    end
  end
  
  #Reads meta-data about the query like keys and count.
  def read_meta
    @result.before_first
    meta = @result.meta_data
    @count = meta.column_count
    
    @keys = []
    1.upto(@count) do |count|
      @keys << meta.column_label(count).to_sym
    end
  end
  
  def fetch
    return false if !@result
    self.read_meta if !@keys
    status = @result.next
    
    if !status
      @result = nil
      @keys = nil
      @count = nil
      return false
    end
    
    if @as_hash
      ret = {}
      1.upto(@keys.length) do |count|
        ret[@keys[count - 1]] = @result.string(count)
      end
    else
      ret = []
      1.upto(@count) do |count|
        ret << @result.string(count)
      end
    end
    
    return ret
  end
  
  def each
    while data = self.fetch
      yield(data)
    end
  end
end