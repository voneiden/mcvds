import gleam/option.{type Option}

pub type Device {
  Device(name: String)
}

pub type ModuleInstance {
  ModuleInstance(module_id: String, module_name: String, instance_name: String)
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
    initval: Int,
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
