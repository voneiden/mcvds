import gleam/dynamic.{field, int, list, optional, string}
import gleam/int as gleam_int
import gleam/result
import mcvds_types

pub fn read_write_decoder(value: dynamic.Dynamic) {
  string(value)
  |> result.try(fn(value) {
    case value {
      "rw" -> Ok(mcvds_types.ReadWrite)
      "w" -> Ok(mcvds_types.Write)
      "r" -> Ok(mcvds_types.Read)
      _ -> Error([dynamic.DecodeError("One of 'rw', 'w', 'r'", value, [])])
    }
  })
}

pub fn hex_decoder(dynamic_value: dynamic.Dynamic) {
  string(dynamic_value)
  |> result.try(fn(string_value) {
    case string_value {
      "0x" <> value ->
        gleam_int.base_parse(value, 16)
        |> result.map_error(fn(_) {
          [dynamic.DecodeError("an integer", value, [])]
        })
      _ ->
        Error([
          dynamic.DecodeError("string starting with '0x'", string_value, []),
        ])
    }
  })
}

pub fn bitfield_decoder() {
  dynamic.decode5(
    mcvds_types.Bitfield,
    field("caption", string),
    field("mask", hex_decoder),
    field("name", string),
    field("rw", read_write_decoder),
    field("values", optional(string)),
  )
}

pub fn register_decoder() {
  dynamic.decode7(
    mcvds_types.Register,
    field("caption", string),
    field("initval", hex_decoder),
    field("name", string),
    field("offset", hex_decoder),
    field("rw", read_write_decoder),
    field("size", int),
    field("bitmasks", list(bitfield_decoder())),
  )
}
