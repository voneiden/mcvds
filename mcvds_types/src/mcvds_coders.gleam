import gleam/dynamic.{any, field, int, list, optional, optional_field, string}
import gleam/int as gleam_int
import gleam/option
import gleam/result
import mcvds_types

pub fn device_decoder() {
  dynamic.decode4(
    mcvds_types.Device,
    field("architecture", string),
    field("family", string),
    field("name", string),
    field("modules", list(module_reference_decoder())),
  )
}

pub fn module_reference_decoder() {
  dynamic.decode3(
    mcvds_types.ModuleReference,
    field("id", string),
    field("name", string),
    field("instances", list(module_instance_decoder())),
  )
}

pub fn module_instance_decoder() {
  dynamic.decode2(
    mcvds_types.ModuleInstance,
    field("name", string),
    optional_list_field("register_groups", instance_register_group_decoder),
  )
}

pub fn instance_register_group_decoder() {
  dynamic.decode4(
    mcvds_types.InstanceRegisterGroup,
    any([
      optional_field("address_space", string),
      field("address_space", optional(string)),
    ]),
    field("name", string),
    any([optional_field("name_in", string), field("name_in", optional(string))]),
    field("offset", hex_decoder),
  )
}

pub fn module_decoder() {
  dynamic.decode4(
    mcvds_types.Module,
    field("caption", string),
    field("id", string),
    field("name", string),
    optional_list_field("register_groups", register_group_decoder),
  )
}

pub fn register_group_decoder() {
  dynamic.decode4(
    mcvds_types.RegisterGroup,
    field("caption", string),
    field("name", string),
    field("size", hex_decoder),
    field("registers", list(register_decoder())),
  )
}

pub fn register_decoder() {
  dynamic.decode7(
    mcvds_types.Register,
    field("caption", string),
    any([
      optional_field("initval", hex_decoder),
      field("initval", optional(hex_decoder)),
    ]),
    field("name", string),
    field("offset", hex_decoder),
    field("rw", read_write_decoder),
    field("size", any([int, int_from_string_decoder])),
    optional_list_field("bitfields", bitfield_decoder),
  )
}

pub fn bitfield_decoder() {
  dynamic.decode5(
    mcvds_types.Bitfield,
    field("caption", string),
    field("mask", hex_decoder),
    field("name", string),
    field("rw", read_write_decoder),
    any([optional_field("values", string), field("values", optional(string))]),
  )
}

pub fn read_write_decoder(value: dynamic.Dynamic) {
  string(value)
  |> result.try(fn(value) {
    case value {
      "RW" -> Ok(mcvds_types.ReadWrite)
      "W" -> Ok(mcvds_types.Write)
      "R" -> Ok(mcvds_types.Read)
      _ -> Error([dynamic.DecodeError("One of 'RW', 'W', 'R'", value, [])])
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

pub fn int_from_string_decoder(value: dynamic.Dynamic) {
  string(value)
  |> result.try(fn(string_value) {
    gleam_int.parse(string_value)
    |> result.replace_error([
      dynamic.DecodeError("int encoded as string", string_value, []),
    ])
  })
}

fn optional_list_field(field_name, field_decoder) {
  fn(value) {
    optional_field(field_name, list(field_decoder()))(value)
    |> result.map(option.unwrap(_, []))
  }
}
