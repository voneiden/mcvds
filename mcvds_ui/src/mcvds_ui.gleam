//// TODO, implement: transform: translate(50px, 0) scale(0.75);

import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/fetch
import gleam/http/request
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import js/utils
import lustre
import lustre/attribute.{class, classes, id} as a
import lustre/effect
import lustre/element.{text}
import lustre/element/html.{div}
import lustre/event as e
import mcvds_coders
import mcvds_types as t
import utils/signal

type Msg {
  ManifestResponse(Result(t.Manifest, FetchOrDecodeError))
  AtdfResponse(Result(t.Atdf, FetchOrDecodeError))
  HighlightSignal(Option(t.Signal))
  SelectSignal(Option(t.Signal))
}

type Model {
  Model(
    atdf: Option(Result(t.Atdf, FetchOrDecodeError)),
    manifest: Option(Result(t.Manifest, FetchOrDecodeError)),
    error: Option(String),
    device: Option(t.Device),
    pinout: Option(t.Pinout),
    signal_map: Dict(String, List(t.Signal)),
    highlighted_signal: Option(t.Signal),
    selected_signal: Option(t.Signal),
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
    Model(
      atdf: None,
      manifest: None,
      error: None,
      device: None,
      pinout: None,
      signal_map: dict.new(),
      highlighted_signal: None,
      selected_signal: None,
    ),
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
        Ok(atdf) -> {
          let device =
            use_option_if_in_list_else_first(atdf.devices, model.device)
          Model(
            ..model,
            atdf: Some(atdf_response),
            device: device,
            pinout: use_option_if_in_list_else_first(atdf.pinouts, model.pinout),
            signal_map: option.map(device, generate_signal_map)
              |> option.unwrap(dict.new()),
          )
        }
        Error(_) -> Model(..model, atdf: Some(atdf_response))
      }
    HighlightSignal(signal) -> Model(..model, highlighted_signal: signal)
    SelectSignal(signal) -> Model(..model, selected_signal: signal)
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

fn main_view(model: Model, manifest: t.Manifest) {
  div(
    [
      class("flex flex-col h-full text-blue-100"),
      e.on_click(SelectSignal(None)),
    ],
    [
      div([class("flex grow")], [
        div(
          [id("sidebar"), class("w-60 border bg-sky-900")],
          view_sidebar(model.device),
        ),
        div(
          [
            id("chip"),
            class("flex grow bg-sky-950"),
            a.style([
              #(
                "background-image",
                "radial-gradient(#000000 1px,transparent 1px)",
              ),
              #("background-size", "10px 10px"),
            ]),
          ],
          [
            view_chip(
              model.atdf,
              model.pinout,
              model.signal_map,
              model.highlighted_signal,
              model.selected_signal,
            ),
          ],
        ),
      ]),
      div([class("flex grow")], [
        div(
          [id("registers"), class("grow border bg-sky-900")],
          view_registry_overview(model.atdf),
        ),
        div([id("documentation"), class("grow border bg-sky-900")], [
          text("doc view"),
        ]),
      ]),
    ],
  )
}

fn view_sidebar(device: Option(t.Device)) {
  case device {
    Some(device) -> [html.h1([], [text(device.name)])]
    None -> []
  }
}

fn view_registry_overview(atdf: Option(Result(t.Atdf, FetchOrDecodeError))) {
  case atdf {
    Some(Ok(atdf)) -> [view_modules(atdf.modules)]
    _ -> [text("mjea")]
  }
}

fn view_modules(modules: List(t.Module)) {
  html.ul(
    [],
    modules
      |> list.sort(fn(m1, m2) { string.compare(m1.name, m2.name) })
      |> list.map(view_module),
  )
}

fn view_module(module: t.Module) {
  html.li([], [
    text(label_module(module)),
    html.ul([], [view_register_groups(module.register_groups)]),
  ])
}

fn label_module(module: t.Module) {
  case module.caption == module.name {
    True -> module.caption
    False -> module.caption <> " (" <> module.name <> ")"
  }
}

fn view_register_groups(register_groups: List(t.RegisterGroup)) {
  html.ul(
    [class("ml-4")],
    register_groups
      |> list.map(fn(register_group) {
        view_registers(register_group.registers)
      })
      |> list.concat(),
  )
}

fn view_registers(registers: List(t.Register)) {
  registers |> list.map(view_register)
}

fn view_register(register: t.Register) {
  html.li([], [text(register.name)])
}

fn view_chip(
  atdf: Option(Result(t.Atdf, FetchOrDecodeError)),
  pinout: Option(t.Pinout),
  signal_map: Dict(String, List(t.Signal)),
  highlighted_signal: Option(t.Signal),
  selected_signal: Option(t.Signal),
) {
  case atdf, pinout {
    Some(Error(error)), _ -> text(string.inspect(error))
    None, _ -> text("no chip")
    _, None -> text("no pinout")
    Some(Ok(atdf)), Some(pinout) ->
      view_soic(atdf, pinout, signal_map, highlighted_signal, selected_signal)
  }
}

fn row_pin_count(package: t.Package) {
  case package {
    t.SOIC8 -> 4
    t.SOIC14 -> 7
  }
}

fn to_px(value: Int) {
  int.to_string(value) <> "px"
}

fn soic_height(pinout: t.Pinout) {
  let pin_row_height = 24
  let pin_row_margin = 10
  to_px({
    let count = row_pin_count(pinout.name)
    pin_row_height * count + pin_row_margin * { count - 1 }
  })
}

fn pins_to_soic_layout(pins: List(t.Pin)) {
  let row_count = list.length(pins) / 2
  case list.split(pins, row_count) {
    #(left, right) -> #(left, right |> list.reverse)
  }
}

fn view_pin(
  pin: t.Pin,
  signals: List(t.Signal),
  row_class: String,
  pin_rounding: String,
  highlighted_signal: Option(t.Signal),
  selected_signal: Option(t.Signal),
) {
  div([class("[&:not(:last-child)]:mb-2.5 h-6 flex"), class(row_class)], [
    div(
      [
        class("flex justify-center items-center text-xs w-6 bg-slate-300"),
        class(pin_rounding),
      ],
      [text(int.to_string(pin.position))],
    ),
    ..view_signals(signals, pin, highlighted_signal, selected_signal)
  ])
}

fn view_signals(
  signals: List(t.Signal),
  pin: t.Pin,
  highlighted_signal: Option(t.Signal),
  selected_signal: Option(t.Signal),
) {
  let view_signal = view_signal(_, highlighted_signal, selected_signal)
  case signals {
    [] -> [view_signal(t.Signal(None, pin.pad, pin.pad, None, pin.pad))]
    _ -> list.map(signals, view_signal)
  }
}

fn highlight_signal(highlighted_signal: Option(t.Signal), signal: t.Signal) {
  highlighted_signal
  |> option.map(fn(highlighted_signal) {
    highlighted_signal.function == signal.function
  })
  |> option.unwrap(False)
}

fn select_signal_classes(selected_signal: Option(t.Signal), signal: t.Signal) {
  selected_signal
  |> option.map(fn(selected_signal) {
    case selected_signal.function == signal.function {
      True -> #("border-2 border-cyan-500", True)
      False -> #("opacity-50", True)
    }
  })
  |> option.unwrap(#("", False))
}

fn view_signal(
  signal: t.Signal,
  highlighted_signal: Option(t.Signal),
  selected_signal: Option(t.Signal),
) {
  let label = signal_label(signal)
  let signal_bg_color = signal.background(signal.function)
  let signal_border = case label {
    "" -> #("", False)
    _ -> #("border", True)
  }
  div(
    [
      // TODO make this cleaner
      class("text-xs rounded w-16 flex justify-center items-center mx-1"),
      class(signal_bg_color),
      classes([
        signal_border,
        #(
          "cursor-pointer border-2 border-cyan-300",
          highlight_signal(highlighted_signal, signal),
        ),
        select_signal_classes(selected_signal, signal),
      ]),
      e.on_mouse_enter(HighlightSignal(Some(signal))),
      e.on_mouse_leave(HighlightSignal(None)),
      e.on("click", fn(event) {
        e.stop_propagation(event)
        Ok(SelectSignal(Some(signal)))
      }),
    ],
    [text(label)],
  )
}

/// For labeling the signal we normally use group + index
/// For IOPORT function the group is PIN, so use the pad 
///   name as it is more familiar, eg "PA4"
/// For OUT group use function name, eg "DAC0 OUT"
fn signal_label(signal: t.Signal) {
  case signal.function, signal.group {
    "IOPORT", _ -> signal.pad
    _, "OUT" -> signal.function <> " " <> "OUT"
    _, _ ->
      signal.group
      <> { signal.index |> option.map(int.to_string(_)) |> option.unwrap("") }
  }
}

fn group_and_order_signals(signals: List(t.Signal)) -> List(List(t.Signal)) {
  signals
  |> list.group(fn(s) { s.function })
  |> dict.values()
  |> list.flat_map(split_duplicate_pads)
  |> list.sort(fn(a, b) { int.compare(list.length(a), list.length(b)) })
  |> list.reverse
}

/// In special cases a function group may contain signals on the same pad.
/// In the case of ATtiny814, the UPDI and RESET signals are on OTHERS function.
/// In these situations the signals need to be split into separate signal groups
/// to avoid blank insertions causing a misalignment
fn split_duplicate_pads(signal_group: List(t.Signal)) -> List(List(t.Signal)) {
  let #(main_group, other_groups) =
    signal_group
    |> list.group(fn(s) { s.pad })
    |> dict.values()
    |> list.fold(#([], []), fn(acc, signal) {
      case signal {
        [] -> acc
        [first, ..rest_of_same_pad] -> #(
          [first, ..acc.0],
          list.prepend(acc.1, rest_of_same_pad),
        )
      }
    })
  [main_group |> list.reverse(), ..other_groups |> list.reverse()]
}

fn fit_signal_group(signal_group: List(t.Signal), available_pads: Set(String)) {
  let signal_pads = signal_group |> list.map(fn(s) { s.pad }) |> set.from_list
  case set.is_subset(signal_pads, available_pads) {
    True -> Ok(#(signal_group, set.difference(available_pads, signal_pads)))
    False -> Error(Nil)
  }
}

fn do_fit_signal_groups(
  signal_groups: List(List(t.Signal)),
  pads: Set(String),
  available_pads: Set(String),
  fitted_signal_groups: List(List(t.Signal)),
) {
  case signal_groups {
    [] -> fitted_signal_groups
    _ ->
      case list.pop_map(signal_groups, fit_signal_group(_, available_pads)) {
        Ok(#(
          #(fitted_signal_group, available_pads_after_fit),
          remaining_signal_groups,
        )) -> {
          do_fit_signal_groups(
            remaining_signal_groups,
            pads,
            available_pads_after_fit,
            [fitted_signal_group, ..fitted_signal_groups],
          )
        }
        Error(_) ->
          case pads == available_pads {
            True -> {
              io.println_error("Fitting has failed, giving up!")
              fitted_signal_groups
            }
            // TODO insert blanks
            False ->
              do_fit_signal_groups(signal_groups, pads, pads, [
                available_pads
                  |> set.to_list
                  |> list.map(fn(pad) { t.Signal(None, "BLANK", "", None, pad) }),
                ..fitted_signal_groups
              ])
          }
      }
  }
}

fn fit_signal_groups(signal_groups: List(List(t.Signal)), pads: Set(String)) {
  do_fit_signal_groups(signal_groups, pads, pads, []) |> list.reverse
}

fn get_signals(device: t.Device, filter_modules: Set(t.ModuleReference)) {
    device.modules
  |> list.filter(fn(module) { set.contains(filter_modules, module) })
  |> list.map(fn(m) { get_signals_for_module_reference(m) })
    |> list.concat
}

fn get_signals_for_module_reference(module_reference: t.ModuleReference) {
  module_reference.instances
    |> list.map(fn(i) { i.signals })
    |> list.concat
}

fn generate_signal_map(device: t.Device, filter_modules: Set(t.ModuleReference)) {
  let signals = get_signals(device, filter_modules)

  let signal_pads = signals |> list.map(fn(s) { s.pad }) |> set.from_list

  // Note: group reverses signal order

  signals
  |> group_and_order_signals
  |> fit_signal_groups(signal_pads)
  |> list.concat
  |> list.group(fn(s) { s.pad })
}

/// DIP / SOIC package is dual in-line, so we can render just left and right side
fn view_soic(
  atdf: t.Atdf,
  pinout: t.Pinout,
  signal_map: Dict(String, List(t.Signal)),
  highlighted_signal: Option(t.Signal),
  selected_signal: Option(t.Signal),
) {
  let #(left_pins, right_pins) = pins_to_soic_layout(pinout.pins)

  div(
    [
      id("soic"),
      class("flex grow self-center"),
      a.style([#("height", soic_height(pinout))]),
    ],
    [
      div(
        [id("soic-left"), class("grow")],
        list.map(left_pins, fn(pin) {
          view_pin(
            pin,
            dict.get(signal_map, pin.pad) |> result.unwrap([]) |> list.reverse,
            "justify-start flex-row-reverse",
            "rounded-l-md",
            highlighted_signal,
            selected_signal,
          )
        }),
      ),
      div([id("soic-middle"), class("flex flex-col w-24")], [
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
            class(
              "flex grow justify-center items-center text-white bg-zinc-800",
            ),
            a.style([#("writing-mode", "vertical-rl")]),
          ],
          [text(atdf.name)],
        ),
      ]),
      div(
        [id("soic-right"), class("grow")],
        list.map(right_pins, fn(pin) {
          view_pin(
            pin,
            dict.get(signal_map, pin.pad) |> result.unwrap([]) |> list.reverse,
            "justify-start",
            "rounded-r-md",
            highlighted_signal,
            selected_signal,
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
