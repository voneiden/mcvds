import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import htmgrrrl as h
import mcvds_types
import simplifile

pub type McvdsType {
  Module(mcvds_types.Module)
  RegisterGroup(mcvds_types.RegisterGroup)
  Register(mcvds_types.Register)
  Bitfield(mcvds_types.Bitfield)
}

fn parse_hex_to_int(hex: String) {
  case hex {
    "0x" <> value -> int.base_parse(value, 16)
    _ -> Error(Nil)
  }
  |> result.map_error(fn(_) { "Could not parse hex '" <> hex <> "'" })
}

fn parse_int(value: String) {
  int.parse(value)
  |> result.map_error(fn(_) { "Could not parse value'" <> value <> "'" })
}

fn parse_rw(rw: String) {
  case rw {
    "RW" -> Ok(mcvds_types.ReadWrite)
    "R" -> Ok(mcvds_types.Read)
    "W" -> Ok(mcvds_types.ReadWrite)
    _ -> Error("Could not parse rw value \"" <> rw <> "\"")
  }
}

fn format_key_error(key, _) {
  "Could not find key '" <> key <> "'"
}

fn dict_get(d, key) {
  dict.get(d, key)
  |> result.map_error(format_key_error(key, _))
}

fn build_module(attrs: List(h.Attribute)) -> Result(McvdsType, String) {
  let d = dict.from_list(list.map(attrs, fn(attr) { #(attr.name, attr.value) }))
  use caption <- result.try(dict_get(d, "caption"))
  use id <- result.try(dict_get(d, "id"))
  use name <- result.try(dict_get(d, "name"))

  Ok(Module(mcvds_types.Module(caption:, id:, name:, register_groups: [])))
}

fn build_register_group(attrs: List(h.Attribute)) -> Result(McvdsType, String) {
  let d = dict.from_list(list.map(attrs, fn(attr) { #(attr.name, attr.value) }))
  use caption <- result.try(dict_get(d, "caption"))

  use name <- result.try(dict_get(d, "name"))
  use size_raw <- result.try(dict_get(d, "size"))
  use size <- result.try(parse_hex_to_int(size_raw))

  Ok(
    RegisterGroup(
      mcvds_types.RegisterGroup(caption:, name:, size:, registers: []),
    ),
  )
}

fn build_register(attrs: List(h.Attribute)) -> Result(McvdsType, String) {
  let d = dict.from_list(list.map(attrs, fn(attr) { #(attr.name, attr.value) }))
  use caption <- result.try(dict_get(d, "caption"))
  use initval <- result.try(
    dict.get(d, "initval")
    |> option.from_result
    |> option.unwrap("0x00")
    |> parse_hex_to_int,
  )
  use name <- result.try(dict_get(d, "name"))
  use offset_raw <- result.try(dict_get(d, "offset"))
  use offset <- result.try(parse_hex_to_int(offset_raw))
  use rw_raw <- result.try(dict_get(d, "rw"))
  use rw <- result.try(parse_rw(rw_raw))
  use size_raw <- result.try(dict_get(d, "size"))
  use size <- result.try(parse_int(size_raw))
  Ok(
    Register(
      mcvds_types.Register(
        caption:,
        initval:,
        name:,
        offset:,
        rw:,
        size:,
        bitfields: [],
      ),
    ),
  )
}

fn build_bitfield(attrs: List(h.Attribute)) -> Result(McvdsType, String) {
  let d = dict.from_list(list.map(attrs, fn(attr) { #(attr.name, attr.value) }))
  use caption <- result.try(dict_get(d, "caption"))
  use mask_raw <- result.try(dict_get(d, "mask"))
  use mask <- result.try(parse_hex_to_int(mask_raw))
  use name <- result.try(dict_get(d, "name"))
  use rw_raw <- result.try(dict_get(d, "rw"))
  use rw <- result.try(parse_rw(rw_raw))
  let values = dict.get(d, "values") |> option.from_result
  Ok(Bitfield(mcvds_types.Bitfield(caption:, mask:, name:, rw:, values:)))
}

pub type ParserState {
  ParserState(
    stack: List(#(option.Option(McvdsType), List(String))),
    results: List(McvdsType),
  )
}

pub fn first_replace(l: List(a), replace_fn: fn(a) -> Result(a, Nil)) {
  case l {
    [first, ..rest] ->
      case replace_fn(first) {
        Ok(replaced) -> Ok(list.prepend(rest, replaced))
        _ -> {
          use rv <- result.try(first_replace(rest, replace_fn))
          Ok(list.prepend(rv, first))
        }
      }
    [] -> Error(Nil)
  }
}

fn prepend_in_parent(
  opt_parent: Option(McvdsType),
  child: McvdsType,
) -> Result(Option(McvdsType), Nil) {
  case opt_parent {
    Some(parent) -> {
      case parent, child {
        Register(register), Bitfield(bitfield) ->
          Ok(
            Some(Register(
              mcvds_types.Register(
                ..register,
                bitfields: list.prepend(register.bitfields, bitfield),
              ),
            )),
          )
        RegisterGroup(register_group), Register(register) ->
          Ok(
            Some(RegisterGroup(
              mcvds_types.RegisterGroup(
                ..register_group,
                registers: [register, ..register_group.registers],
              ),
            )),
          )
        Module(module), RegisterGroup(register_group) ->
          Ok(
            Some(Module(
              mcvds_types.Module(
                ..module,
                register_groups: [register_group, ..module.register_groups],
              ),
            )),
          )
        _, _ -> Error(Nil)
      }
    }
    None -> Error(Nil)
  }
}

fn prepend_in_stack_parent(
  stack_item: #(Option(McvdsType), List(String)),
  child: McvdsType,
) {
  case stack_item {
    #(parent, path) ->
      result.map(prepend_in_parent(parent, child), fn(new_parent) {
        #(new_parent, path)
      })
  }
}

fn build_mdvcs_type(
  stack_path: List(String),
  attrs: List(h.Attribute),
) -> Result(Option(McvdsType), String) {
  //io.debug(stack_path)
  case stack_path {
    ["module", "modules", ..] -> result.map(build_module(attrs), Some)
    ["register-group", "module", ..] ->
      result.map(build_register_group(attrs), Some)
    ["register", ..] -> result.map(build_register(attrs), Some)
    ["bitfield", ..] -> result.map(build_bitfield(attrs), Some)
    _ -> Ok(None)
  }
}

// TODO ParserState could be a Result and on Error we just yeet outta here
fn atdf_parser2(state: ParserState, _, event: h.SaxEvent) {
  case event {
    h.StartElement(_, local_name, _, attrs) -> {
      let stack_parent_path =
        list.first(state.stack) |> result.map(pair.second) |> result.unwrap([])
      let stack_path = [local_name, ..stack_parent_path]
      case build_mdvcs_type(stack_path, attrs) {
        Ok(value) ->
          ParserState(
            ..state,
            stack: list.prepend(state.stack, #(value, stack_path)),
          )
        Error(msg) -> {
          io.debug("Error building '" <> local_name <> "': " <> msg)
          ParserState(
            ..state,
            stack: list.prepend(state.stack, #(None, stack_path)),
          )
        }
      }
    }

    h.EndElement(..) ->
      case state.stack {
        [#(None, _), ..rest] -> ParserState(..state, stack: rest)
        [#(Some(self), _), ..rest] -> {
          case first_replace(rest, prepend_in_stack_parent(_, self)) {
            Ok(updated_rest) -> ParserState(..state, stack: updated_rest)
            _ ->
              ParserState(
                ..state,
                stack: rest,
                results: list.prepend(state.results, self),
              )
          }
        }
        [] -> state
      }
    _ -> state
  }
}

// pub fn parse_atdf(file_name: String) {
//   use xml <- result.try(simplifile.read(from: file_name))
//   Ok(h.sax(xml, AtdfParserState([], []), atdf_parser))
// }

pub fn parse_atdf(file_name: String) {
  use xml <- result.try(simplifile.read(from: file_name))
  Ok(h.sax(xml, ParserState([], []), atdf_parser2))
}
