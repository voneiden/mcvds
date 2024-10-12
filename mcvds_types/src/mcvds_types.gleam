import gleam/option.{type Option}

pub type Atdf {
  Atdf(devices: List(Device), modules: List(Module))
}

pub type Device {
  Device(
    architecture: String,
    family: String,
    name: String,
    modules: List(ModuleReference),
  )
}

pub type ModuleReference {
  ModuleReference(id: String, name: String, instances: List(ModuleInstance))
}

pub type ModuleInstance {
  ModuleInstance(name: String, register_groups: List(InstanceRegisterGroup))
}

pub type InstanceRegisterGroup {
  InstanceRegisterGroup(
    address_space: Option(String),
    name: String,
    name_in: Option(String),
    offset: Int,
  )
}

pub type Module {
  Module(
    caption: String,
    id: String,
    name: String,
    register_groups: List(RegisterGroup),
  )
}

pub type RegisterGroup {
  RegisterGroup(
    caption: String,
    name: String,
    size: Int,
    registers: List(Register),
  )
}

pub type Register {
  Register(
    caption: String,
    initval: Option(Int),
    name: String,
    offset: Int,
    rw: ReadWrite,
    size: Int,
    bitfields: List(Bitfield),
  )
}

pub type Bitfield {
  Bitfield(
    caption: String,
    mask: Int,
    name: String,
    rw: ReadWrite,
    values: Option(String),
  )
}

pub type ReadWrite {
  ReadWrite
  Read
  Write
}
