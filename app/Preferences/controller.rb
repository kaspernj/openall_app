class PreferencesController < Rho::RhoController
  def index
    render :action => :index, :back => Rho::RhoConfig.start_path
  end
  
  def save
    Knj::Opts.set("openall_host", @params["texhost"])
    Knj::Opts.set("openall_port", @params["texport"])
    Knj::Opts.set("openall_ssl", Knj::Web.checkval(@params["chessl"], 1, 0))
    Knj::Opts.set("openall_username", @params["texuser"])
    Knj::Opts.set("openall_password", Base64.strict_encode64(@params["texpasswd"]))
    
    render :action => :save_success, :back => Rho::RhoConfig.start_path
  end
end