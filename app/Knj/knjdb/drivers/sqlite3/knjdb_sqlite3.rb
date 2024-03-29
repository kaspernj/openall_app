#This class handels SQLite3-specific behaviour.
class KnjDB_sqlite3
  attr_reader :knjdb, :conn, :escape_table, :escape_col, :escape_val, :esc_table, :esc_col, :symbolize
  attr_accessor :tables, :cols, :indexes
  
  #Constructor. This should not be called manually.
  def initialize(knjdb_ob)
    @escape_table = "`"
    @escape_col = "`"
    @escape_val = "'"
    @esc_table = "`"
    @esc_col = "`"
    
    @knjdb = knjdb_ob
    @path = @knjdb.opts[:path] if @knjdb.opts[:path]
    @path = @knjdb.opts["path"] if @knjdb.opts["path"]
    @symbolize = true if !@knjdb.opts.key?(:return_keys) or @knjdb.opts[:return_keys] == "symbols"
    
    @knjdb.opts[:subtype] = "java" if !@knjdb.opts.key?(:subtype) and RUBY_ENGINE == "jruby"
    raise "No path was given." if !@path
    
    if @knjdb.opts[:subtype] == "java"
      if @knjdb.opts[:sqlite_driver]
        require @knjdb.opts[:sqlite_driver]
      else
        require "#{File.dirname(__FILE__)}/../../../jruby/sqlitejdbc-v056.jar"
      end
      
      require "java"
      import "org.sqlite.JDBC"
      @conn = java.sql.DriverManager::getConnection("jdbc:sqlite:#{@knjdb.opts[:path]}")
      @stat = @conn.createStatement
    elsif @knjdb.opts[:subtype] == "rhodes"
      @conn = SQLite3::Database.new(@path, @path)
    else
      @conn = SQLite3::Database.open(@path)
      @conn.results_as_hash = true
      @conn.type_translation = false
    end
  end
  
  #Executes a query against the driver.
  def query(string)
    begin
      if @knjdb.opts[:subtype] == "rhodes"
        return KnjDB_sqlite3_result.new(self, @conn.execute(string, string))
      elsif @knjdb.opts[:subtype] == "java"
        begin
          return KnjDB_sqlite3_result_java.new(self, @stat.executeQuery(string))
        rescue java.sql.SQLException => e
          if e.message.to_s.index("query does not return ResultSet") != nil
            return KnjDB_sqlite3_result_java.new(self, nil)
          else
            raise e
          end
        end
      else
        return KnjDB_sqlite3_result.new(self, @conn.execute(string))
      end
    rescue => e
      #Add SQL to the error message.
      raise e.class, "#{e.message} (SQL: #{string})"
    end
  end
  
  #SQLite3 driver doesnt support unbuffered queries??
  alias query_ubuf query
  
  #Escapes a string to be safe to used in a query.
  def escape(string)
    #This code is taken directly from the documentation so we dont have to rely on the SQLite3::Database class. This way it can also be used with JRuby and IronRuby...
    #http://sqlite-ruby.rubyforge.org/classes/SQLite/Database.html
    return string.to_s.gsub(/'/, "''")
  end
  
  #Escapes a string to be used as a column.
  def esc_col(string)
    string = string.to_s
    raise "Invalid column-string: #{string}" if string.index(@escape_col) != nil
    return string
  end
  
  alias :esc_table :esc_col
  alias :esc :escape
  
  #Returns the last inserted ID.
  def lastID
    return @conn.last_insert_row_id if @conn.respond_to?(:last_insert_row_id)
    return self.query("SELECT last_insert_rowid() AS id").fetch[:id].to_i
  end
  
  #Closes the connection to the database.
  def close
    @conn.close
  end
  
  #Starts a transaction, yields the database and commits.
  def transaction
    @conn.transaction do
      yield(@knjdb)
    end
  end
end

#This class handels results when running in JRuby.
class KnjDB_sqlite3_result_java
  def initialize(driver, rs)
    @index = 0
    retkeys = driver.knjdb.opts[:return_keys]
    
    if rs
      metadata = rs.getMetaData
      columns_count = metadata.getColumnCount
      
      @rows = []
      while rs.next
        row_data = {}
        for i in (1..columns_count)
          col_name = metadata.getColumnName(i)
          col_name = col_name.to_s.to_sym if retkeys == "symbols"
          row_data[col_name] = rs.getString(i)
        end
        
        @rows << row_data
      end
    end
  end
  
  #Returns a single result.
  def fetch
    return false if !@rows
    ret = @rows[@index]
    return false if !ret
    @index += 1
    return ret
  end
  
  #Loops over every result and yields them.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end

#This class handels the result when running MRI (or others).
class KnjDB_sqlite3_result
  #Constructor. This should not be called manually.
  def initialize(driver, result_array)
    @result_array = result_array
    @index = 0
    
    if driver.knjdb.opts[:return_keys] == "symbols"
      @symbols = true
    else
      @symbols = false
    end
  end
  
  #Returns a single result.
  def fetch
    result_hash = @result_array[@index]
    return false if !result_hash
    @index += 1
    
    ret = {}
    result_hash.each do |key, val|
      if Knj::Php::is_numeric(key)
        #do nothing.
      elsif @symbols and !key.is_a?(Symbol)
        ret[key.to_sym] = val
      else
        ret[key] = val
      end
    end
    
    return ret
  end
  
  #Loops over every result yielding them.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end