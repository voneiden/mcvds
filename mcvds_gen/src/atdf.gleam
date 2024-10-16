import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import htmgrrrl as h
import mcvds_coders
import mcvds_types
import simplifile

fn attrs_to_data(attrs: List(h.Attribute)) -> Dict(String, dynamic.Dynamic) {
  attrs
  |> list.map(fn(attr) { #(attr.name, dynamic.from(attr.value)) })
  |> dict.from_list
}

fn element_is_data(name: String) {
  list.contains(
    [
      "device", "instance", "module", "register-group", "register", "bitfield",
      "pinout", "pin",
    ],
    name,
  )
}

pub type ParserState {
  ParserState(
    stack: List(Dict(String, dynamic.Dynamic)),
    modules: List(dynamic.Dynamic),
    devices: List(dynamic.Dynamic),
    pinouts: List(dynamic.Dynamic),
    decode_errors: List(dynamic.DecodeError),
  )
}

pub fn first_replace(l: List(a), replace_fn: fn(a) -> Result(a, Nil)) {
  case l {
    [first, ..rest] ->
      case replace_fn(first) {
        Ok(replaced) -> Ok([replaced, ..rest])
        _ -> {
          use rv <- result.try(first_replace(rest, replace_fn))
          Ok([first, ..rv])
        }
      }
    [] -> Error(Nil)
  }
}

//fn insert_in_field(data: List(#(String, String)), 
fn prepend_to_dynamic_list(
  dynamic_list: dynamic.Dynamic,
  dynamic_value: dynamic.Dynamic,
) {
  dynamic_list
  |> dynamic.list(dynamic.dynamic)
  |> result.map(fn(l) { l |> list.prepend(dynamic_value) |> dynamic.from })
}

fn prepend_dynamic_value_to_key(
  map: Dict(String, dynamic.Dynamic),
  key: String,
  value: dynamic.Dynamic,
) -> Result(Dict(String, dynamic.Dynamic), List(dynamic.DecodeError)) {
  map
  |> dict.get(key)
  |> result.unwrap(dynamic.from([]))
  |> prepend_to_dynamic_list(value)
  |> result.try(fn(new_value) { Ok(dict.insert(map, key, new_value)) })
}

fn insert_to_parent(parent, name, child) {
  case name {
    "bitfield" -> "bitfields"
    "register" -> "registers"
    "register-group" -> "register_groups"
    "instance" -> "instances"
    "module" -> "modules"
    "pin" -> "pins"
    _ -> {
      io.println("Unhandled name: '" <> name <> "'")
      panic
    }
  }
  |> prepend_dynamic_value_to_key(parent, _, child)
}

fn atdf_parser(state: ParserState, _, event: h.SaxEvent) {
  case event {
    h.StartElement(_, local_name, _, attrs) ->
      case element_is_data(local_name) {
        True -> {
          ParserState(..state, stack: [attrs_to_data(attrs), ..state.stack])
        }
        False -> state
      }

    h.EndElement(_, local_name, _) ->
      case element_is_data(local_name) {
        True ->
          case state.stack {
            [self, parent, ..rest] -> {
              let insert_result =
                insert_to_parent(parent, local_name, dynamic.from(self))
              case insert_result {
                Ok(new_parent) ->
                  ParserState(..state, stack: [new_parent, ..rest])
                Error(errors) ->
                  ParserState(
                    ..state,
                    decode_errors: list.append(state.decode_errors, errors),
                  )
              }
            }
            [self] ->
              case local_name {
                "module" ->
                  ParserState(
                    ..state,
                    stack: [],
                    modules: [dynamic.from(self), ..state.modules],
                  )
                "device" ->
                  ParserState(
                    ..state,
                    stack: [],
                    devices: [dynamic.from(self), ..state.devices],
                  )
                "pinout" ->
                  ParserState(
                    ..state,
                    stack: [],
                    pinouts: [dynamic.from(self), ..state.pinouts],
                  )
                _ -> panic
              }
            [] -> state
          }
        False -> state
      }
    _ -> state
  }
}

pub type AtdfParseError {
  FileError(simplifile.FileError)
  NameError
  SaxError
  DecodeError(String, List(dynamic.DecodeError))
}

fn name_from_file(file_path: String) {
  use file_name <- result.try(
    file_path
    |> string.split("/")
    |> list.last,
  )
  use name <- result.try(
    file_name
    |> string.split(".")
    |> list.first,
  )
  Ok(name)
}

pub fn parse_atdf(file_name: String) {
  use xml <- result.try(
    simplifile.read(from: file_name) |> result.map_error(FileError),
  )
  use parser_state <- result.try(
    h.sax(xml, ParserState([], [], [], [], []), atdf_parser)
    |> result.map_error(fn(_) { SaxError }),
  )

  use name <- result.try(
    name_from_file(file_name) |> result.map_error(fn(_) { NameError }),
  )

  let modules =
    list.map(parser_state.modules, mcvds_coders.module_decoder())
    |> result.all()
  let devices =
    list.map(parser_state.devices, mcvds_coders.device_decoder())
    |> result.all()
  let pinouts =
    list.map(parser_state.pinouts, mcvds_coders.pinout_decoder())
    |> result.all()

  case modules, devices, pinouts {
    Ok(modules), Ok(devices), Ok(pinouts) ->
      Ok(mcvds_types.Atdf(name, devices, modules, pinouts))
    Error(error), _, _ -> Error(DecodeError("Modules", error))
    _, Error(error), _ -> Error(DecodeError("Devices", error))
    _, _, Error(error) -> Error(DecodeError("Pinouts", error))
  }
}

pub fn export_atdf(atdf: mcvds_types.Atdf) {
  simplifile.write(
    "../mcvds_ui/priv/static/defs/" <> atdf.name <> ".json",
    mcvds_coders.atdf_encoder(atdf) |> json.to_string,
  )
}
