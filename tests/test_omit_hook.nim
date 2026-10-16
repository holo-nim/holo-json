import holo_json

type User = object
  id: int
  names: seq[string]

template omitField(format: JsonDump, user: User, field: static string): bool =
  when field == "names":
    user.names.len == 0
  else:
    false

import std/json

let user1 = User(id: 123, names: @["abc", "def"])
doAssert user1.toJson.fromJsonAs(JsonNode) == %*{"id": 123, "names": ["abc", "def"]}
let user2 = User(id: 456, names: @[])
doAssert user2.toJson.fromJsonAs(JsonNode) == %*{"id": 456}

type
  Zoom = object
    startX, startY: float
    zoomWidth, zoomHeight: float # ratios of total width and height
  View = object
    width, height: float
    zoom: Zoom

let defaultZoom = Zoom(startX: 0, startY: 0, zoomWidth: 1.0, zoomHeight: 1.0)

proc omitField(format: JsonDump, zoom: Zoom, field: string): bool {.inline.} =
  case field
  of "start_x", "start_y":
    result = zoom.startX == 0 and zoom.startY == 0
  of "zoom_width":
    result = zoom.zoomWidth == 1.0
  of "zoom_height":
    result = zoom.zoomHeight == 1.0

proc omitField(format: JsonDump, view: View, field: static string): bool {.inline.} =
  when field == "zoom":
    result = view.zoom == defaultZoom
  else:
    result = false

let view1 = View(width: 400, height: 300, zoom: defaultZoom)
doAssert view1.toJson.fromJsonAs(JsonNode) == %*{"width": 400.0, "height": 300.0}
let view2 = View(width: 600, height: 500, zoom: Zoom(startX: 0, startY: 1, zoomWidth: 1, zoomHeight: 2))
doAssert view2.toJson.fromJsonAs(JsonNode) ==
  %*{"width": 600.0, "height": 500.0, "zoom": {"start_x": 0.0, "start_y": 1.0, "zoom_height": 2.0}}

