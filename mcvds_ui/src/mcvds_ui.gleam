import gleam/dict
import gleam/dynamic
import gleam/fetch
import gleam/http/request
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import js/utils
import lustre
import lustre/attribute.{class, id} as a
import lustre/effect
import lustre/element.{text}
import lustre/element/html.{div}
import mcvds_coders
import mcvds_types

type Msg {
  ManifestResponse(Result(mcvds_types.Manifest, FetchOrDecodeError))
  AtdfResponse(Result(mcvds_types.Atdf, FetchOrDecodeError))
}

type Model {
  Model(
    atdf: Option(Result(mcvds_types.Atdf, FetchOrDecodeError)),
    manifest: Option(Result(mcvds_types.Manifest, FetchOrDecodeError)),
    error: Option(String),
    device: Option(mcvds_types.Device),
    pinout: Option(mcvds_types.Pinout),
  )
}

type FetchOrDecodeError {
  FetchError(fetch.FetchError)
  DecodeErrors(dynamic.DecodeErrors)
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) {
  #(
    Model(atdf: None, manifest: None, error: None, device: None, pinout: None),
    effect.batch([get_manifest(), get_atdf("ATtiny814.json")]),
  )
}

@internal
pub fn use_option_if_in_list_else_first(l: List(a), opt: Option(a)) {
  case option.map(opt, list.contains(l, _)) {
    Some(True) -> opt
    _ -> list.first(l) |> option.from_result
  }
}

fn update(model: Model, msg: Msg) {
  let model = case msg {
    ManifestResponse(manifest) -> Model(..model, manifest: Some(manifest))
    AtdfResponse(atdf_response) ->
      case atdf_response {
        Ok(atdf) ->
          Model(
            ..model,
            atdf: Some(atdf_response),
            device: use_option_if_in_list_else_first(atdf.devices, model.device),
            pinout: use_option_if_in_list_else_first(atdf.pinouts, model.pinout),
          )
        Error(_) -> Model(..model, atdf: Some(atdf_response))
      }
  }
  #(model, effect.none())
}

fn view(model: Model) {
  case model.manifest {
    Some(Ok(manifest)) -> main_view(model, manifest)
    Some(Error(error)) -> text("Oh fok: " <> string.inspect(error))
    None -> text("Hold up")
  }
}

fn main_view(model: Model, manifest: mcvds_types.Manifest) {
  div([class("flex flex-col h-full")], [
    div([class("flex grow")], [
      div([id("sidebar"), class("w-60 bg-amber-700")], [text("sidebar")]),
      div([id("chip"), class("flex grow bg-cyan-500")], [
        view_chip(model.atdf, model.device, model.pinout),
      ]),
    ]),
    div([class("flex grow")], [
      div([id("registers"), class("grow bg-pink-200")], [text("reg view")]),
      div([id("documentation"), class("grow bg-fuchsia-600")], [
        text("doc view"),
      ]),
    ]),
  ])
}

fn view_chip(
  atdf: Option(Result(mcvds_types.Atdf, FetchOrDecodeError)),
  device: Option(mcvds_types.Device),
  pinout: Option(mcvds_types.Pinout),
) {
  case atdf, device, pinout {
    Some(Error(error)), _, _ -> text(string.inspect(error))
    None, _, _ -> text("no chip")
    _, None, _ -> text("no device")
    _, _, None -> text("no pinout")
    Some(Ok(atdf)), Some(device), Some(pinout) ->
      view_soic(atdf, device, pinout)
  }
}

fn row_pin_count(package: mcvds_types.Package) {
  case package {
    mcvds_types.SOIC8 -> 4
    mcvds_types.SOIC14 -> 7
  }
}

fn to_px(value: Int) {
  int.to_string(value) <> "px"
}

fn soic_height(pinout: mcvds_types.Pinout) {
  let pin_row_height = 24
  let pin_row_margin = 10
  to_px({
    let count = row_pin_count(pinout.name)
    pin_row_height * count + pin_row_margin * { count - 1 }
  })
}

fn pins_to_soic_layout(pins: List(mcvds_types.Pin)) {
  let row_count = list.length(pins) / 2
  case list.split(pins, row_count) {
    #(left, right) -> #(left, right |> list.reverse)
  }
}

fn signals_to_soic_layout(
  signals: List(mcvds_types.Signal),
  left: List(mcvds_types.Pin),
) {
  let left_pads = list.map(left, fn(pin) { pin.pad })
  list.partition(signals, fn(signal) { list.contains(left_pads, signal.pad) })
}

fn view_pin(
  pin: mcvds_types.Pin,
  signals: List(mcvds_types.Signal),
  row_class: String,
  pin_rounding: String,
) {
  div([class("[&:not(:last-child)]:mb-2.5 h-6 flex"), class(row_class)], [
    div(
      [
        class("flex justify-center items-center text-xs w-6 bg-slate-300"),
        class(pin_rounding),
      ],
      [text(int.to_string(pin.position))],
    ),
    ..view_signals(pin, signals)
  ])
}

fn view_signals(pin: mcvds_types.Pin, signals: List(mcvds_types.Signal)) {
  case signals {
    [] -> [
      div(
        [
          class(
            "text-xs border rounded w-14 flex justify-center items-center mx-1",
          ),
        ],
        [text(pin.pad)],
      ),
    ]
    _ -> list.map(signals, view_signal)
  }
}

fn view_signal(signal: mcvds_types.Signal) {
  div(
    [class("text-xs border rounded w-14 flex justify-center items-center mx-1")],
    [text(signal_label(signal))],
  )
}

fn signal_label(signal: mcvds_types.Signal) {
  case signal.function, signal.group {
    "IOPORT", _ -> signal.pad
    _, "OUT" -> signal.function <> " " <> "OUT"
    _, _ ->
      signal.group
      <> { signal.index |> option.map(int.to_string(_)) |> option.unwrap("") }
  }
}

/// DIP / SOIC package is dual in-line, so we can render just left and right side
fn view_soic(
  atdf: mcvds_types.Atdf,
  device: mcvds_types.Device,
  pinout: mcvds_types.Pinout,
) {
  let #(left_pins, right_pins) = pins_to_soic_layout(pinout.pins)
  let signals =
    device.modules
    |> list.map(fn(m) { m.instances })
    |> list.concat
    |> list.map(fn(i) { i.signals })
    |> list.concat
  let #(left_signals, right_signals) =
    signals_to_soic_layout(signals, left_pins)
  let signal_map = list.group(signals, fn(s) { s.pad })
  div(
    [
      id("soic"),
      class("flex grow self-center bg-sky-800"),
      a.style([#("height", soic_height(pinout))]),
    ],
    [
      div(
        [id("soic-left"), class("grow bg-sky-700")],
        list.map(left_pins, fn(pin) {
          view_pin(
            pin,
            dict.get(signal_map, pin.pad) |> result.unwrap([]),
            "justify-start flex-row-reverse",
            "rounded-l-md",
          )
        }),
      ),
      div([id("soic-middle"), class("flex flex-col w-24 bg-sky-600")], [
        div(
          [
            id("pin1-marker"),
            class("absolute rounded-md w-2.5 h-2.5 mt-2.5 ml-2.5 bg-slate-200"),
          ],
          [],
        ),
        div(
          [
            id("device-name"),
            class("flex grow justify-center items-center"),
            a.style([#("writing-mode", "vertical-rl")]),
          ],
          [text(atdf.name)],
        ),
      ]),
      div(
        [id("soic-right"), class("grow bg-sky-500")],
        list.map(right_pins, fn(pin) {
          view_pin(
            pin,
            dict.get(signal_map, pin.pad) |> result.unwrap([]),
            "justify-start",
            "rounded-r-md",
          )
        }),
      ),
    ],
  )
}

fn to_wrapped_fetch_error() {
  promise.map(_, result.map_error(_, fn(e) { FetchError(e) }))
}

fn to_wrapped_decode_errors() {
  promise.map(_, result.map_error(_, fn(e) { DecodeErrors(e) }))
}

fn get_manifest() {
  effect.from(fn(dispatch) {
    let response = {
      let assert Ok(req) =
        request.to(utils.origin() <> "/priv/static/defs/manifest.json")
      use resp <- promise.try_await(
        fetch.send(req)
        |> to_wrapped_fetch_error(),
      )
      use resp <- promise.try_await(
        fetch.read_json_body(resp) |> to_wrapped_fetch_error(),
      )

      use manifest <- promise.try_await(
        mcvds_coders.manifest_decoder()(resp.body)
        |> promise.resolve
        |> to_wrapped_decode_errors(),
      )

      promise.resolve(Ok(manifest))
    }
    promise.await(response, fn(result) {
      dispatch(ManifestResponse(result))
      promise.resolve(Nil)
    })
    Nil
  })
}

fn get_atdf(name) {
  effect.from(fn(dispatch) {
    let response = {
      let assert Ok(req) =
        request.to(utils.origin() <> "/priv/static/defs/" <> name)
      use resp <- promise.try_await(
        fetch.send(req)
        |> to_wrapped_fetch_error(),
      )
      use resp <- promise.try_await(
        fetch.read_json_body(resp) |> to_wrapped_fetch_error(),
      )

      use manifest <- promise.try_await(
        mcvds_coders.atdf_decoder()(resp.body)
        |> promise.resolve
        |> to_wrapped_decode_errors(),
      )

      promise.resolve(Ok(manifest))
    }
    promise.await(response, fn(result) {
      dispatch(AtdfResponse(result))
      promise.resolve(Nil)
    })
    Nil
  })
}
