#This class helps handeling time-columns in databases.
class Knj::Db::Dbtime
  #These variables return information about the object.
  attr_reader :hours, :mins, :secs, :total_secs
  
  #Initializes the object from arguments useually given by Knj::Datarow.
  def initialize(args)
    args = {:time => args} if args.is_a?(String)
    
    raise "Invalid arguments given." if !args.is_a?(Hash)
    raise "No time given." if !args[:time]
    raise "Invalid time given." if !args[:time].is_a?(String)
    
    match = args[:time].match(/^(\d+):(\d+):(\d+)$/)
    raise "Could not understand time format." if !match
    
    @hours = match[1].to_i
    @mins = match[2].to_i
    @secs = match[3].to_i
    
    @total_secs = @hours * 3600
    @total_secs += @mins * 60
    @total_secs += @secs
  end
  
  #Returns the total amount of hours.
  def hours_total
    return (@total_secs.to_f / 3600)
  end
  
  #Return the total amount of minutes.
  def mins_total
    return (@total_secs.to_f / 60)
  end
end