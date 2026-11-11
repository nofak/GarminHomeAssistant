[Home](../README.md) | [Switches](Switches.md) | [Actions](Actions.md) | [Templates](Templates.md) | [Numeric](Numeric.md) | [Select](Select.md) | [Glance](Glance.md) | [Icons & Detail](Icons_Detail.md) | [Background Service](../BackgroundService.md) | [Wi-Fi](../Wi-Fi.md) | [HTTP Headers](../HTTP_Headers.md) | [Trouble Shooting](../TroubleShooting.md) | [Version History](../HISTORY.md)

# Item Icons & Detail View

## Item Icons

By default a menu item shows an icon for its type, e.g. the "i" in a circle for an `info` item. The optional `icon` field replaces it with an icon describing what the item is about, so a long menu is easier to scan at a glance.

```json
{
  "name": "Washing Machine",
  "icon": "washer",
  "type": "info",
  "content": "{{ states('sensor.washing_machine_status') }}"
}
```

The `icon` field works with `info`, `tap` and `group` items. `toggle` items keep their switch, as it shows the state. The icons are only shown when the "Show the type icons" setting is on. An unknown name falls back to the type icon, so a menu using `icon` still works with older versions of the application.

Available icons (from [Google Material Symbols](https://fonts.google.com/icons), in the same style as the type icons):

| Name | Material Symbol | Name | Material Symbol |
|---|---|---|---|
| `garage` | garage_home | `washer` | local_laundry_service |
| `heating` | heat | `dryer` | laundry |
| `boiler` | local_fire_department | `dishwasher` | dishwasher_gen |
| `thermostat` | device_thermostat | `vacuum` | vacuum |
| `hot_water` | water_heater | `light` | lightbulb |
| `valve` | valve | `power` | power |
| `outdoor` | partly_cloudy_day | `lock` | lock |
| `floor_heat` | heat_pump_balance | `fan` | mode_fan |
| `appliances` | electrical_services | `battery` | battery_full |
| | | `bell` | notifications |

To add an icon, put its 48x48 SVG into `resources-icons-48` with the colour classes used by the other icons, add it to `drawables.xml`, run `iconResize.py` to create the other sizes, and add the name to `HomeAssistantMenuItemFactory.customIcon()` and to the schema.

## Detail View

Selecting an `info` item (one without a `tap_action`) previously did nothing. It now opens a full screen view with the whole text of the item, wrapped over several lines. This helps on round screens, where longer [template](Templates.md) results get cut off in the menu.

The optional `detail` field adds a template that is rendered by Home Assistant only when the view opens, so it costs nothing while the menu is shown. It can show more than fits in the menu, e.g. a trend, today's minimum and maximum, or a graph:

* The first line is drawn larger, as the headline.
* A line starting with `~` followed by comma separated numbers is drawn as a line graph, e.g. `~20.5,20.7,21.0,21.4`.
* Other lines are drawn as smaller text.

```json
{
  "name": "Outside",
  "icon": "outdoor",
  "type": "info",
  "content": "{{ states('sensor.outside_temperature') }} °C",
  "detail": "{{ states('sensor.outside_temperature') }} °C\n~{{ state_attr('sensor.outside_history', 'values') | join(',') }}\nmin {{ state_attr('sensor.outside_history', 'values') | min }} · max {{ state_attr('sensor.outside_history', 'values') | max }}"
}
```

### Providing values for a graph

Templates cannot read Home Assistant's history, so the values for a graph have to be kept by a sensor. A trigger based template sensor can sample a value every 15 minutes and keep the last 96 samples (24 hours) in an attribute:

```yaml
template:
  - triggers:
      - trigger: time_pattern
        minutes: "/15"
    sensor:
      - name: Outside history
        state: "{{ states('sensor.outside_temperature') }}"
        attributes:
          values: >-
            {% set v = states('sensor.outside_temperature') %}
            {% set old = this.attributes.get('values', []) if this is defined else [] %}
            {{ ((old + [v | float | round(1)]) if v | is_number else old)[-96:] }}
```

Exclude such sensors from the `recorder`, as the attribute changes every time and its history is not needed.

### Keeping the menu small

The menu is cached on the watch with a limit of 8 kB per stored value, so long `detail` templates can make the menu too big to cache. Home Assistant's [reusable templates](https://www.home-assistant.io/docs/configuration/templating/#reusing-templates) (macros in `custom_templates/*.jinja`) keep the menu small:

```jinja
{# custom_templates/watch.jinja #}
{%- macro outside_detail() -%}
{{ states('sensor.outside_temperature') }} °C
~{{ state_attr('sensor.outside_history', 'values') | join(',') }}
{%- endmacro %}
```

```json
"detail": "{% from 'watch.jinja' import outside_detail %}{{ outside_detail() }}"
```
