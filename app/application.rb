require 'rho/rhoapplication'

require "timeout"
require "thread"
require "digest"
require "digest/md5"
require "base64"

$knjpath = "Knj/"
module Knj; end
require "#{$knjpath}rhodes/rhodes.rb"

require "wref/wref.rb"
require "tsafe/tsafe.rb"

require "#{$knjpath}knjdb/libknjdb.rb"
require "#{$knjpath}objects.rb"
require "#{$knjpath}datarow.rb"
require "#{$knjpath}strings.rb"
require "#{$knjpath}web.rb"

class Openall_time_applet
  class Models
    
  end
end

require "openall_time_applet/models/organisation"
require "openall_time_applet/models/task"
require "openall_time_applet/models/timelog"
require "openall_time_applet/models/worktime"

require "openall_time_applet/conf/db_schema.rb"

$rhodes = Knj::Rhodes.new(
  :module => Openall_time_applet::Models,
  :class_pre => "",
  :require => false,
  :schema => Openall_time_applet::DB_SCHEMA
)

class AppApplication < Rho::RhoApplication
  def initialize
    # Tab items are loaded left->right, @tabs[0] is leftmost tab in the tab-bar
    # Super must be called *after* settings @tabs!
    @tabs = nil
    
    #To remove default toolbar uncomment next line:
    @@toolbar = nil
    super
    
    @default_menu = {}

    # Uncomment to set sync notification callback to /app/Settings/sync_notify.
    # SyncEngine::set_objectnotify_url("/app/Settings/sync_notify")
    #SyncEngine.set_notification(-1, "/app/Settings/sync_notify", '')
  end
end
