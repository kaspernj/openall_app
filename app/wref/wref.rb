require "java" if RUBY_ENGINE == "jruby"

#A simple weak-reference framework with mapping. Only handles the referencing of objects.
#===Examples
# user_obj = ob.get(:User, 1)
# weak_ref = Wref.new(user_obj)
# user_obj = nil
# sleep 0.5
# GC.start
#
# begin
#   user_obj = weak_ref.get
#   print "The user still exists in memory and has ID #{user.id}."
# rescue Wref::Recycled
#   print "The user has been removed from memory."
# end
class Wref
  #Returns the classname of the object.
  attr_reader :class_name
  
  #Returns the object-ID which is used to look up the ObjectSpace (if not running JRuby).
  attr_reader :id
  
  #Initializes various variables.
  def initialize(obj)
    if RUBY_ENGINE == "jruby"
      @weakref = java.lang.ref.WeakReference.new(obj)
    else
      @id = obj.__id__
      @class_name = obj.class.name.to_sym
      ObjectSpace.define_finalizer(obj, self.method(:destroy))
      
      if obj.respond_to?(:__object_unique_id__)
        @unique_id = obj.__object_unique_id__
      end
    end
  end
  
  #Destroyes most variables on the object, releasing memory and returning 'Wref::Recycled' all the time. It takes arguments because it can be called from destructor of the original object. It doesnt use the arguments for anything.
  def destroy(*args)
    @id = nil
    @class_name = nil
    @unique_id = nil
    @weakref = nil
  end
  
  #Returns the object that this weak reference holds or raises Wref::Recycled.
  # begin
  #   obj = wref.get
  #   print "Object still exists in memory."
  # rescue Wref::Recycled
  #   print "Object has been garbage-collected."
  # end
  def get
    begin
      if RUBY_ENGINE == "jruby"
        raise Wref::Recycled if !@weakref
        obj = @weakref.get
        
        if obj == nil
          raise Wref::Recycled
        else
          return obj
        end
      else
        raise Wref::Recycled if !@class_name or !@id
        obj = ObjectSpace._id2ref(@id)
        
        #Some times this class-name will be nil for some reason - knj
        obj_class_name = obj.class.name
        
        if !obj_class_name or @class_name != obj_class_name.to_sym or @id != obj.__id__
          raise Wref::Recycled
        end
        
        if @unique_id
          raise Wref::Recycled if !obj.respond_to?(:__object_unique_id__) or obj.__object_unique_id__ != @unique_id
        end
        
        return obj
      end
    rescue RangeError, TypeError
      raise Wref::Recycled
    end
  end
  
  #Returns true if the reference is still alive.
  # print "The object still exists in memory." if wref.alive?
  def alive?
    begin
      self.get
      return true
    rescue Wref::Recycled
      return false
    end
  end
  
  #Makes Wref compatible with the normal WeakRef.
  alias weakref_alive? alive?
  alias __getobj__ get
end

#A weak hash-map.
#===Examples
# map = Wref_map.new
# map[1] = obj
# obj = nil
# 
# sleep 0.5
# 
# begin
#   obj = map[1]
#   print "Object still exists in memory."
# rescue Wref::Recycled
#   print "Object has been garbage-collected."
# end
#
# obj = map.get!(1)
# print "Object still exists in memory." if obj
class Wref_map
  def initialize(args = nil)
    @map = {}
    @ids = {}
    @mutex = Mutex.new
  end
  
  #Sets a new object in the map with a given ID.
  def set(id, obj)
    wref = Wref.new(obj)
    
    @mutex.synchronize do
      @map[id] = wref
      @ids[obj.__id__] = id
    end
    
    #JRuby cant handle this atm... Dunno why...
    if RUBY_ENGINE != "jruby"
      ObjectSpace.define_finalizer(obj, self.method("delete_by_id"))
    end
    
    return nil
  end
  
  #Returns a object by ID or raises a RefError.
  #===Examples
  # begin
  #   obj = map[1]
  #   print "Object still exists in memory."
  # rescue Wref::Recycled
  #   print "Object has been garbage-collected."
  # end
  def get(id)
    begin
      @mutex.synchronize do
        raise Wref::Recycled if !@map.key?(id)
        return @map[id].get
      end
    rescue Wref::Recycled => e
      self.delete(id)
      raise e
    end
  end
  
  #The same as 'get' but returns nil instead of WeakRef-error. This can be used to avoid writing lots of code.
  #===Examples
  # obj = map.get!(1)
  # print "Object still exists in memory." if obj
  def get!(id)
    begin
      return self.get(id)
    rescue Wref::Recycled
      return nil
    end
  end
  
  #Scans the whole map and removes dead references. After the implementation of automatic clean-up by using ObjectSpace.define_finalizer, there should be no reason to call this method.
  def clean
    keys = nil
    @mutex.synchronize do
      keys = @map.keys
    end
    
    keys.each do |key|
      begin
        self.get(key) #this will remove the key if the object no longer exists.
      rescue Wref::Recycled
        #ignore.
      end
    end
    
    return nil
  end
  
  #Returns true if a given key exists and the object it holds is alive.
  def valid?(key)
    @mutex.synchronize do
      return false if !@map.key?(key)
      
      begin
        @map[key].get
        return true
      rescue Wref::Recycled
        return false
      end
    end
  end
  
  #Returns true if the given key exists in the hash.
  #===Examples
  # print "Key exists but we dont know if the value has been garbage-collected." if map.key?(1)
  def key?(key)
    @mutex.synchronize do
      return @map.key?(key)
    end
  end
  
  #Returns the length of the hash. This may not be true since invalid objects is also counted.
  def length
    @mutex.synchronize do
      return @map.length
    end
  end
  
  #Cleans the hash and returns the length. This is slower but more accurate than the ordinary length that just returns the hash-length.
  def length_valid
    self.clean
    
    @mutex.synchronize do
      return @map.length
    end
  end
  
  #Deletes a key in the hash.
  def delete(key)
    @mutex.synchronize do
      wref = @map[key]
      @ids.delete(wref.id) if wref
      @map.delete(key)
    end
  end
  
  #This method is supposed to remove objects when finalizer is called by ObjectSpace.
  def delete_by_id(object_id)
    @mutex.synchronize do
      id = @ids[object_id]
      @map.delete(id)
      @ids.delete(object_id)
    end
  end
  
  #Make it hash-compatible.
  alias has_key? key?
  alias [] get
  alias []= set
end

#This error is raised when an object in a wref has been garbage-collected.
class Wref::Recycled < RuntimeError; end