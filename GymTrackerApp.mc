import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Sensor;
import Toybox.System;

var gExercises as Array<Dictionary> = [];
var gCurrentIdx as Number = 0;
var gSetNumber as Number = 1;
var gHeartRate as Number = 0;
var gEditMode as Number = 0;
var gStatus as String = "START=Ulozit | BACK=Rezim";

class GymTrackerApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
        loadWorkoutFromStorage();
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensor));
    }

    function loadWorkoutFromStorage() as Void {
        var saved = Storage.getValue("workout_plan");
        if (saved != null && (saved as Array).size() > 0) {
            gExercises = saved as Array<Dictionary>;
        } else {
            gExercises = [
                {"name" => "Benchpress", "weight" => 80.0, "reps" => 10, "step" => 2.5},
                {"name" => "Drep",       "weight" => 100.0, "reps" => 8,  "step" => 5.0},
                {"name" => "Biceps",     "weight" => 15.0, "reps" => 12, "step" => 1.25},
                {"name" => "Ramena",     "weight" => 8.0,  "reps" => 15, "step" => 0.5}
            ];
            Storage.setValue("workout_plan", gExercises);
        }
    }

    function onSensor(sensorInfo as Sensor.Info) as Void {
        gHeartRate = (sensorInfo.heartRate != null) ? sensorInfo.heartRate : 0;
        WatchUi.requestUpdate();
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Dictionary && data.hasKey("plan")) {
            var newPlan = data.get("plan") as Array<Dictionary>;
            if (newPlan.size() > 0) {
                gExercises = newPlan;
                gCurrentIdx = 0;
                gSetNumber = 1;
                Storage.setValue("workout_plan", gExercises);
                gStatus = "Plan nahrany!";
                if (Attention has :vibrate) {
                    Attention.vibrate([new Attention.VibeProfile(100, 400)]);
                }
            }
        }
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new GymView(), new GymDelegate() ];
    }
}

class GymView extends WatchUi.View {
    function initialize() { View.initialize(); }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (gExercises.size() == 0) { return; }

        var ex = gExercises[gCurrentIdx];
        var name = ex.get("name").toString();
        var weight = ex.get("weight").toFloat();
        var reps = ex.get("reps").toNumber();
        var step = ex.get("step").toFloat();

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        var hrText = (gHeartRate > 0) ? ("Tep: " + gHeartRate + " bpm") : "Tep: -- bpm";
        dc.drawText(w / 2, h * 0.10, Graphics.FONT_XTINY, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((gEditMode == 2) ? Graphics.COLOR_GREEN : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var exTitle = (gCurrentIdx + 1) + "/" + gExercises.size() + " " + name + " (" + gSetNumber + ".s)";
        dc.drawText(w / 2, h * 0.25, Graphics.FONT_SMALL, exTitle, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((gEditMode == 0) ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var weightStr = "Vaha: " + weight.format("%.2f") + " kg (krok " + step.format("%.2f") + ")";
        dc.drawText(w / 2, h * 0.45, Graphics.FONT_SMALL, weightStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor((gEditMode == 1) ? Graphics.COLOR_GREEN : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var repsStr = "Opakovani: " + reps + " x";
        dc.drawText(w / 2, h * 0.62, Graphics.FONT_SMALL, repsStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.78, Graphics.FONT_XTINY, "Podrz UP = Poradi a krok", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h * 0.88, Graphics.FONT_XTINY, gStatus, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class GymDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function onPreviousPage() as Boolean { adjustValue(1); return true; }
    function onNextPage() as Boolean { adjustValue(-1); return true; }

    function adjustValue(dir as Number) as Void {
        var ex = gExercises[gCurrentIdx];
        if (gEditMode == 0) {
            var step = ex.get("step").toFloat();
            var newW = ex.get("weight").toFloat() + (dir * step);
            if (newW >= 0.0) { ex.put("weight", newW); }
        } else if (gEditMode == 1) {
            var newR = ex.get("reps").toNumber() + dir;
            if (newR >= 1) { ex.put("reps", newR); }
        } else if (gEditMode == 2) {
            gCurrentIdx = (gCurrentIdx + dir + gExercises.size()) % gExercises.size();
            gSetNumber = 1;
        }
        Storage.setValue("workout_plan", gExercises);
        WatchUi.requestUpdate();
    }

    function onBack() as Boolean {
        gEditMode = (gEditMode + 1) % 3;
        if (gEditMode == 0) { gStatus = "Upravujes: VAHA"; }
        else if (gEditMode == 1) { gStatus = "Upravujes: OPAKOVANI"; }
        else { gStatus = "Upravujes: VYBER CVIKU"; }
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Nastaveni cviku"});
        menu.addItem(new WatchUi.MenuItem("Posunout cvik VYS", null, :move_up, null));
        menu.addItem(new WatchUi.MenuItem("Posunout cvik NIZ", null, :move_down, null));
        menu.addItem(new WatchUi.MenuItem("Krok: 0.50 kg", null, :step_05, null));
        menu.addItem(new WatchUi.MenuItem("Krok: 1.25 kg", null, :step_125, null));
        menu.addItem(new WatchUi.MenuItem("Krok: 2.50 kg", null, :step_25, null));
        menu.addItem(new WatchUi.MenuItem("Krok: 5.00 kg", null, :step_50, null));
        menu.addItem(new WatchUi.MenuItem("Ukoncit aplikaci", null, :exit_app, null));
        WatchUi.pushView(menu, new GymMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onSelect() as Boolean {
        var ex = gExercises[gCurrentIdx];
        var record = {
            "exercise" => ex.get("name"),
            "set" => gSetNumber,
            "weight" => ex.get("weight"),
            "reps" => ex.get("reps"),
            "hr" => gHeartRate
        };

        var history = Storage.getValue("workout_logs") as Array;
        if (history == null) { history = []; }
        history.add(record);
        Storage.setValue("workout_logs", history);

        Communications.transmit(record, null, new GymCommListener());

        gSetNumber += 1;
        gStatus = "Serie " + (gSetNumber - 1) + " ulozena!";
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 200)]);
        }
        WatchUi.requestUpdate();
        return true;
    }
}

class GymMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var ex = gExercises[gCurrentIdx];

        if (id == :move_up && gCurrentIdx > 0) {
            var temp = gExercises[gCurrentIdx - 1];
            gExercises[gCurrentIdx - 1] = ex;
            gExercises[gCurrentIdx] = temp;
            gCurrentIdx -= 1;
            gStatus = "Cvik posunut vys!";
        } else if (id == :move_down && gCurrentIdx < gExercises.size() - 1) {
            var temp = gExercises[gCurrentIdx + 1];
            gExercises[gCurrentIdx + 1] = ex;
            gExercises[gCurrentIdx] = temp;
            gCurrentIdx += 1;
            gStatus = "Cvik posunut niz!";
        } else if (id == :step_05) {  ex.put("step", 0.5); }
          else if (id == :step_125) { ex.put("step", 1.25); }
          else if (id == :step_25)  { ex.put("step", 2.5); }
          else if (id == :step_50)  { ex.put("step", 5.0); }
          else if (id == :exit_app) { System.exit(); }

        Storage.setValue("workout_plan", gExercises);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

class GymCommListener extends Communications.ConnectionListener {
    function initialize() { ConnectionListener.initialize(); }
    function onComplete() as Void {}
    function onError() as Void {}
}
