Openall_time_applet::DB_SCHEMA = {
  "tables" => {
    "Option" => {
      "columns" => [
        {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
        {"name" => "title", "type" => "varchar"},
        {"name" => "value", "type" => "text"}
      ]
    },
    "Organisation" => {
      "columns" => [
        {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
        {"name" => "openall_uid", "type" => "int"},
        {"name" => "name", "type" => "varchar"}
      ],
      "indexes" => [
        "openall_uid"
      ]
    },
    "Task" => {
      "columns" => [
        {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
        {"name" => "openall_uid", "type" => "int"},
        {"name" => "organisation_id", "type" => "int"},
        {"name" => "title", "type" => "varchar"}
      ],
      "indexes" => [
        "openall_uid",
        "organisation_id",
      ]
    },
    "Timelog" => {
      "columns" => [
        {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
        {"name" => "task_id", "type" => "int"},
        {"name" => "time", "type" => "int"},
        {"name" => "time_transport", "type" => "int"},
        {"name" => "descr", "type" => "text"},
        {"name" => "sync_need", "type" => "enum", "maxlength" => "'0','1'", "default" => 0},
        {"name" => "sync_last", "type" => "datetime"}
      ],
      "indexes" => [
        "task_id"
      ]
    },
    "Worktime" => {
      "columns" => [
        {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
        {"name" => "openall_uid", "type" => "int"},
        {"name" => "task_id", "type" => "int"},
        {"name" => "timestamp", "type" => "datetime"},
        {"name" => "worktime", "type" => "int"},
        {"name" => "transporttime", "type" => "int"},
        {"name" => "comment", "type" => "text"}
      ]
    }
  }
}