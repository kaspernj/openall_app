#This class reads .po-files generated by something like POEdit and can be used to run multi-language applications or websites.
class Knj::Gettext_threadded
  #Hash that contains all translations loaded.
  attr_reader :langs
  
  #Config-hash that contains encoding and more.
  attr_reader :args
  
  #Initializes various data.
  def initialize(args = {})
    @args = {
      :encoding => "utf-8"
    }.merge(args)
    @langs = {}
    @dirs = []
    load_dir(@args["dir"]) if @args["dir"]
  end
  
  #Loads a 'locales'-directory with .mo- and .po-files and fills the '@langs'-hash.
  #===Examples
  # gtext.load_dir("#{File.dirname(__FILE__)}/../locales")
  def load_dir(dir)
    @dirs << dir
    check_folders = ["LC_MESSAGES", "LC_ALL"]
    
    Dir.new(dir).each do |file|
      fn = "#{dir}/#{file}"
      if File.directory?(fn) and file.match(/^[a-z]{2}_[A-Z]{2}$/)
        @langs[file] = {} if !@langs[file]
        
        check_folders.each do |fname|
          fpath = "#{dir}/#{file}/#{fname}"
          
          if File.exists?(fpath) and File.directory?(fpath)
            Dir.new(fpath).each do |pofile|
              if pofile.match(/\.po$/)
                pofn = "#{dir}/#{file}/#{fname}/#{pofile}"
                
                cont = nil
                File.open(pofn, "r", {:encoding => @args[:encoding]}) do |fp|
                  cont = fp.read.encode("utf-8")
                end
                
                cont.scan(/msgid\s+\"(.+)\"\nmsgstr\s+\"(.+)\"\n\n/) do |match|
                  @langs[file][match[0]] = match[1].to_s.encode("utf-8")
                end
              end
            end
          end
        end
      end
    end
  end
  
  #Translates a given string to a given locale from the read .po-files.
  #===Examples
  # str = "Hello" #=> "Hello"
  # gtext.trans("da_DK", str) #=> "Hej"
  def trans(locale, str)
    locale = locale.to_s
    str = str.to_s
    
    if !@langs.key?(locale)
      raise "Locale was not found: '#{locale}' in '#{@langs.keys.join(", ")}'."
    end
    
    return str if !@langs[locale].key?(str)
    return @langs[locale][str]
  end
  
  #This function can be used to make your string be recognized by gettext tools.
  def gettext(str, locale)
    return trans(locale, str)
  end
  
  #Returns a hash with the language ID string as key and the language human-readable-title as value.
  def lang_opts
    langs = {}
    @langs.keys.sort.each do |lang|
      title = nil
      
      @dirs.each do |dir|
        title_file_path = "#{dir}/#{lang}/title.txt"
        if File.exists?(title_file_path)
          title = File.read(title_file_path, {:encoding => @args[:encoding]}).to_s.strip
        else
          title = lang.to_s.strip
        end
        
        break if title
      end
      
      langs[lang] = title
    end
    
    return langs
  end
end