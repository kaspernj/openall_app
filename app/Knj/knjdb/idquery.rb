#This class takes a lot of IDs and runs a query against them.
class Knj::Db::Idquery
  #An array containing all the IDs that will be looked up.
  attr_reader :ids
  
  #Constructor.
  #===Examples
  # idq = Knj::Db::Idquery(:db => db, :table => :users)
  # idq.ids + [1, 5, 9]
  # idq.each do |user|
  #   print "Name: #{user[:name]}\n"
  # end
  def initialize(args, &block)
    @args = args
    @ids = []
    @debug = @args[:debug]
    
    if @args[:query]
      @args[:db].q(@args[:query]) do |data|
        @args[:col] = data.keys.first if !@args[:col]
        
        if data.is_a?(Array)
          @ids << data.first
        else
          @ids << data[@args[:col]]
        end
      end
    end
    
    @args[:col] = :id if !@args[:col]
    @args[:size] = 200 if !@args[:size]
    
    if block
      raise "No query was given but a block was." if !@args[:query]
      self.each(&block)
    end
  end
  
  #Fetches results.
  #===Examples
  # data = idq.fetch #=> Hash
  def fetch
    return nil if !@args
    
    if @res
      data = @res.fetch if @res
      @res = nil if !data
      return data if data
    end
    
    @res = new_res if !@res
    if !@res
      destroy
      return nil
    end
    
    data = @res.fetch
    if !data
      destroy
      return nil
    end
    
    return data
  end
  
  #Yields a block for every result.
  #===Examples
  # idq.each do |data|
  #   print "Name: #{data[:name]}\n"
  # end
  def each
    while data = self.fetch
      yield(data)
    end
  end
  
  private
  
  #Spawns a new database-result to read from.
  def new_res
    table_esc = "`#{@args[:db].esc_table(@args[:table])}`"
    col_esc = "`#{@args[:db].esc_col(@args[:col])}`"
    ids = @ids.shift(@args[:size])
    
    if ids.empty?
      destroy
      return nil
    end
    
    ids_sql = Knj::ArrayExt.join(
      :arr => ids,
      :callback => proc{|val| @args[:db].esc(val)},
      :sep => ",",
      :surr => "'"
    )
    
    query_str = "SELECT * FROM #{table_esc} WHERE #{table_esc}.#{col_esc} IN (#{ids_sql})"
    print "Query: #{query_str}\n" if @debug
    
    return @args[:db].q(query_str)
  end
  
  #Removes all variables on the object. This is done when no more results are available.
  def destroy
    @args = nil
    @ids = nil
    @debug = nil
  end
end