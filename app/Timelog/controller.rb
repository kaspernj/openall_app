class TimelogController < Rho::RhoController
  def edit
    if @params["id"].to_i > 0
      timelog = $rhodes.ob.get(:Timelog, @params["id"])
      @descr = timelog[:descr]
      @time = timelog.time_as_human
      @transport = timelog.time_transport_as_human
    end
    
    render :action => :edit
  end
  
  def save
    if @params["textime"] == ""
      time_secs = 0
    else
      begin
        time_secs = Knj::Strings.human_time_str_to_secs(@params["textime"])
      rescue => e
        raise _("Invalid time-format entered.")
      end
    end
    
    if @params["textransport"] == ""
      time_transport_secs = 0
    else
      begin
        time_transport_secs = Knj::Strings.human_time_str_to_secs(@params["textransport"])
      rescue => e
        raise _("Invalid transport-time-format entered.")
      end
    end
    
    save_hash = {
      :descr => @params["texdescr"],
      :time => time_secs,
      :time_transport => time_transport_secs
    }
    
    if @params["id"].to_i > 0
      timelog = $rhodes.ob.get(:Timelog, @params["id"])
      timelog.update(save_hash)
    else
      timelog = $rhodes.ob.add(:Timelog, save_hash)
    end
    
    render :action => :save_success
  end
end