//-----------------------------------------------------------------------------------
//
// Distributed under MIT Licence
//   See https://github.com/house-of-abbey/GarminHomeAssistant/blob/main/LICENSE.
//
//-----------------------------------------------------------------------------------

using Toybox.Communications;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

//! Full screen view of an information menu item.
//!
//! Shows the menu item's text wrapped over several lines. When the menu item defines a
//! "detail" template, it is rendered by Home Assistant when the view opens and its lines
//! replace the text. A line starting with "~" followed by comma separated numbers is drawn
//! as a line graph (e.g. a day of temperature samples), other lines as text. The first text
//! line is drawn larger, as the headline value.
//
class HomeAssistantDetailView extends WatchUi.View {
    private var mTitle    as Lang.String;
    private var mText     as Lang.String;
    private var mTemplate as Lang.String?;
    private var mLoading  as Lang.Boolean = false;

    //! Class Constructor
    //!
    //! @param title    Menu item label.
    //! @param text     Rendered template text of the menu item.
    //! @param template Optional detail template to render on Home Assistant.
    //
    function initialize(title as Lang.String, text as Lang.String, template as Lang.String?) {
        WatchUi.View.initialize();
        mTitle    = title;
        mText     = text;
        mTemplate = template;
    }

    //! Request the detail template when the view is shown.
    //
    function onShow() as Void {
        if (mTemplate != null && !mLoading) {
            mLoading = true;
            Communications.makeWebRequest(
                Settings.getApiUrl() + "/webhook/" + Settings.getWebhookId(),
                {
                    "type" => "render_template",
                    "data" => { "detail" => { "template" => mTemplate } }
                },
                {
                    :method       => Communications.HTTP_REQUEST_METHOD_POST,
                    :headers      => Settings.augmentHttpHeaders({
                        "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                    }),
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onReturnDetail)
            );
        }
    }

    //! Callback with the rendered detail template.
    //
    function onReturnDetail(
        responseCode as Lang.Number,
        data         as Null or Lang.Dictionary or Lang.String
    ) as Void {
        if (responseCode == 200 && data instanceof Lang.Dictionary && data["detail"] instanceof Lang.String) {
            mText     = data["detail"] as Lang.String;
            mTemplate = null; // rendered, keep the result
        } else {
            mText = mText + "\n(" + responseCode + ")";
        }
        mLoading = false;
        WatchUi.requestUpdate();
    }

    //! Split text into lines.
    //
    private function splitLines(s as Lang.String) as Lang.Array<Lang.String> {
        var lines = [] as Lang.Array<Lang.String>;
        var i = s.find("\n");
        while (i != null) {
            var line = s.substring(0, i) as Lang.String;
            if (!line.equals("")) {
                lines.add(line);
            }
            s = s.substring(i + 1, s.length()) as Lang.String;
            i = s.find("\n");
        }
        if (!s.equals("")) {
            lines.add(s);
        }
        return lines;
    }

    //! Parse "~1.0,2.5,3" into numbers.
    //
    private function parseSeries(s as Lang.String) as Lang.Array<Lang.Float> {
        var values = [] as Lang.Array<Lang.Float>;
        s = s.substring(1, s.length()) as Lang.String;
        var i = s.find(",");
        while (true) {
            var part = (i == null ? s : s.substring(0, i)) as Lang.String;
            var v = part.toFloat();
            if (v != null) {
                values.add(v);
            }
            if (i == null) {
                break;
            }
            s = s.substring(i + 1, s.length()) as Lang.String;
            i = s.find(",");
        }
        return values;
    }

    //! Draw a line graph of the values inside the given box.
    //
    private function drawGraph(dc as Graphics.Dc, values as Lang.Array<Lang.Float>, x as Lang.Number, y as Lang.Number, w as Lang.Number, h as Lang.Number) as Void {
        var n = values.size();
        if (n < 2) {
            return;
        }
        var lo = values[0];
        var hi = values[0];
        for (var i = 1; i < n; i++) {
            if (values[i] < lo) { lo = values[i]; }
            if (values[i] > hi) { hi = values[i]; }
        }
        var range = hi - lo;
        if (range < 0.001) {
            range = 1.0;
            lo = lo - 0.5;
        }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y + h, x + w, y + h);
        dc.setColor(0x00CCFF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var px = x;
        var py = y + h - ((values[0] - lo) / range * h).toNumber();
        for (var i = 1; i < n; i++) {
            var nx = x + (w * i / (n - 1));
            var ny = y + h - ((values[i] - lo) / range * h).toNumber();
            dc.drawLine(px, py, nx, ny);
            px = nx;
            py = ny;
        }
        dc.setPenWidth(1);
        dc.fillCircle(px, py, 3);
    }

    //! Draw the title and the lines.
    //!
    //! @param dc Device context
    //
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var y = (h * 0.10).toNumber();
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, mTitle, Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(Graphics.FONT_XTINY) + 2;

        var lines  = splitLines(mText);
        var graphs = 0;
        var texts  = 0;
        for (var i = 0; i < lines.size(); i++) {
            if (lines[i].find("~") == 0) { graphs++; } else { texts++; }
        }

        // Plain text only (menu item text or no graph): wrap it in the middle of the screen.
        if (graphs == 0) {
            var area = new WatchUi.TextArea({
                :text          => mText + (mLoading ? "\n..." : ""),
                :color         => Graphics.COLOR_WHITE,
                :font          => [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY],
                :justification => Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER,
                :locX          => (w * 0.1).toNumber(),
                :locY          => y,
                :width         => (w * 0.8).toNumber(),
                :height        => (h * 0.85).toNumber() - y
            });
            area.draw(dc);
            return;
        }

        // Headline + graphs + small text lines, stacked.
        var bottom   = (h * 0.90).toNumber();
        var headH    = dc.getFontHeight(Graphics.FONT_SMALL);
        var smallH   = dc.getFontHeight(Graphics.FONT_XTINY);
        var textH    = (texts > 0 ? headH : 0) + (texts > 1 ? (texts - 1) * smallH : 0);
        var graphH   = (bottom - y - textH - graphs * 6) / graphs;
        if (graphH > 70) { graphH = 70; }
        var first = true;
        for (var i = 0; i < lines.size(); i++) {
            var line = lines[i];
            if (line.find("~") == 0) {
                var gw = (w * 0.70).toNumber();
                drawGraph(dc, parseSeries(line), (w - gw) / 2, y + 3, gw, graphH);
                y += graphH + 6;
            } else {
                var font = first ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
                dc.setColor(first ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, font, line, Graphics.TEXT_JUSTIFY_CENTER);
                y += dc.getFontHeight(font);
                first = false;
            }
        }
    }
}
