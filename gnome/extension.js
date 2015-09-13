const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Main = imports.ui.main;
const St = imports.gi.St;

let button, monitor;

function _refresh(sfile, text) {
   let result = function(monitor, a_file, other_file, event_type) {
      text.text = "...";
      if (event_type ==  Gio.FileMonitorEvent.DELETED) {
         text.text = "??:??";
      } else if (event_type == Gio.FileMonitorEvent.CHANGED || event_type == Gio.FileMonitorEvent.CREATED || event_type == Gio.FileMonitorEvent.MOVED) {
         let file = Gio.file_new_for_path(sfile);
         file.load_contents_async(null, function (source, result) {
            let [ok, contents, etag_out] = source.load_contents_finish(result);
            if (ok) {
               let left = parseInt(contents);
               let h = left / 60;
               let m = left % 60;
               if (h < 1 && m < 30) {
                  text.remove_style_class_name('counter-label-cool');
                  text.add_style_class_name('counter-label-hot');
               } else {
                  text.remove_style_class_name('counter-label-hot');
                  text.add_style_class_name('counter-label-cool');
               }
               text.text = "%02d:%02d".format(h, m);
            } else {
               text.text = "??:??";
            }
         });
      }
   };
   return result;
}

function init() {
   let sfile = "/tmp/parentroller/%s.left".format(GLib.get_user_name());
   button = new St.Bin({
      style_class: 'panel-button',
      reactive: false,
      can_focus: false,
      x_fill: true,
      y_fill: false,
      track_hover: false
   });
   let text = new St.Label({
      style_class: 'counter-label-cool',
      text: "Parentrol"
   });
   monitor = Gio.File.new_for_path(sfile).monitor_file(Gio.FileMonitorFlags.NONE, null);
   let refresh = _refresh(sfile, text);
   monitor.id = monitor.connect('changed', refresh);
   refresh(monitor, null, null, Gio.FileMonitorEvent.CREATED);
   button.set_child(text);
}

function enable() {
   Main.panel._rightBox.insert_child_at_index(button, 0);
}

function disable() {
   monitor.disconnect(monitor.id);
   Main.panel._rightBox.remove_child(button);
}
