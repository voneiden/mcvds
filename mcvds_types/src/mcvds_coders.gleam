import gleam/dynamic.{any, field, int, list, optional, optional_field, string}
import gleam/int as gleam_int
import gleam/json as j
import gleam/option
import gleam/result
import mcvds_types

pub fn atdf_decoder() {
  dynamic.decode4(
    mcvds_types.Atdf,
    field("name", string),
    field("devices", list(device_decoder())),
    field("modules", list(module_decoder())),
    field("pinouts", list(pinout_decoder())),
  )
}

pub fn atdf_encoder(atdf: mcvds_types.Atdf) {
  j.object([
    #("name", j.string(atdf.name)),
    #("devices", j.array(atdf.devices, device_encoder)),
    #("modules", j.array(atdf.modules, module_encoder)),
    #("pinouts", j.array(atdf.pinouts, pinout_encoder)),
  ])
}

pub fn device_decoder() {
  dynamic.decode4(
    mcvds_types.Device,
    field("architecture", string),
    field("family", string),
    field("name", string),
    field("modules", list(module_reference_decoder())),
  )
}

pub fn device_encoder(device: mcvds_types.Device) {
  j.object([
    #("architecture", j.string(device.architecture)),
    #("family", j.string(device.family)),
    #("name", j.string(device.name)),
    #("modules", j.array(device.modules, module_reference_encoder)),
  ])
}

pub fn module_reference_decoder() {
  dynamic.decode3(
    mcvds_types.ModuleReference,
    field("id", string),
    field("name", string),
    field("instances", list(module_instance_decoder())),
  )
}

pub fn module_reference_encoder(module_reference: mcvds_types.ModuleReference) {
  j.object([
    #("id", j.string(module_reference.id)),
    #("name", j.string(module_reference.name)),
    #("instances", j.array(module_reference.instances, module_instance_encoder)),
  ])
}

pub fn module_instance_decoder() {
  dynamic.decode2(
    mcvds_types.ModuleInstance,
    field("name", string),
    optional_list_field("register_groups", instance_register_group_decoder),
  )
}

pub fn module_instance_encoder(module_reference: mcvds_types.ModuleInstance) {
  j.object([
    #("name", j.string(module_reference.name)),
    #(
      "register_groups",
      j.array(module_reference.register_groups, instance_register_group_encoder),
    ),
  ])
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

pub fn instance_register_group_encoder(
  instance_register_group: mcvds_types.InstanceRegisterGroup,
) {
  j.object([
    #(
      "address_space",
      j.nullable(instance_register_group.address_space, j.string),
    ),
    #("name", j.string(instance_register_group.name)),
    #("name_in", j.nullable(instance_register_group.name_in, j.string)),
    #("offset", hex_encoder(instance_register_group.offset)),
  ])
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

pub fn module_encoder(module: mcvds_types.Module) {
  j.object([
    #("caption", j.string(module.caption)),
    #("id", j.string(module.id)),
    #("name", j.string(module.name)),
    #(
      "register_groups",
      j.array(module.register_groups, register_group_encoder),
    ),
  ])
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

pub fn register_group_encoder(register_group: mcvds_types.RegisterGroup) {
  j.object([
    #("caption", j.string(register_group.caption)),
    #("name", j.string(register_group.name)),
    #("size", hex_encoder(register_group.size)),
    #("registers", j.array(register_group.registers, register_encoder)),
  ])
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

pub fn register_encoder(register: mcvds_types.Register) {
  j.object([
    #("caption", j.string(register.caption)),
    #("initval", j.nullable(register.initval, hex_encoder)),
    #("name", j.string(register.name)),
    #("offset", hex_encoder(register.offset)),
    #("rw", read_write_encoder(register.rw)),
    #("size", j.int(register.size)),
    #("bitfields", j.array(register.bitfields, bitfield_encoder)),
  ])
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

pub fn bitfield_encoder(bitfield: mcvds_types.Bitfield) {
  j.object([
    #("caption", j.string(bitfield.caption)),
    #("mask", hex_encoder(bitfield.mask)),
    #("name", j.string(bitfield.name)),
    #("rw", read_write_encoder(bitfield.rw)),
    #("values", j.nullable(bitfield.values, j.string)),
  ])
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

pub fn read_write_encoder(value) {
  j.string(case value {
    mcvds_types.ReadWrite -> "RW"
    mcvds_types.Write -> "W"
    mcvds_types.Read -> "R"
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

pub fn hex_encoder(value) {
  j.string("0x" <> gleam_int.to_base16(value))
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

pub fn pinout_decoder() {
  dynamic.decode2(
    mcvds_types.Pinout,
    field("name", string),
    field("pins", list(pin_decoder())),
  )
}

pub fn pinout_encoder(pinout: mcvds_types.Pinout) {
  j.object([
    #("name", j.string(pinout.name)),
    #("pins", j.array(pinout.pins, pin_encoder)),
  ])
}

pub fn pin_decoder() {
  dynamic.decode2(
    mcvds_types.Pin,
    field("pad", string),
    field("position", any([int, int_from_string_decoder])),
  )
}

pub fn pin_encoder(pin: mcvds_types.Pin) {
  j.object([#("pad", j.string(pin.pad)), #("position", j.int(pin.position))])
}
